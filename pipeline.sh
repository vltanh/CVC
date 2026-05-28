#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CVC_ROOT="${SCRIPT_DIR}"
HELPER_SCRIPT_DIR="${CVC_ROOT}/scripts"
METHOD_SCRIPT_DIR="${HELPER_SCRIPT_DIR}/methods"
INVOKE_DIR="$(pwd)"

edgelist="${1:-}"
out_root="${2:-}"

default_merge_method="ClusterMerger"
merge_method="${default_merge_method}"
run_wcc=0
weighting_strategy=0
threshold=0.5
unweight=1
final_algo="leiden-cpm-0.01+wcc"
merge_id=""
stage_timeout="${PIPELINE_TIMEOUT:-5d}"
methods_set=0
PYTHON_CMD=("${PYTHON:-python}")
flow_iter_bin="${FLOW_ITER_BIN:-${CVC_ROOT}/bin/flow-iter}"
cluster_merger_bin="${CLUSTER_MERGER_BIN:-${CVC_ROOT}/bin/cluster_merger}"
rtrex_bin="${RTREX_BIN:-${CVC_ROOT}/bin/RTRex}"
wcc_bin="${WCC_BIN:-}"
pamcon_bin="${PAMCON_BIN:-${CVC_ROOT}/bin/consensus}"

# Defaults are finalized after argument parsing because they depend on
# --merge-method.
METHODS=()

usage() {
    cat <<EOF
Usage: $0 EDGELIST OUT_ROOT [OPTIONS]

Options:
  --merge-method METHOD       ClusterMerger or pamcon (default: ${default_merge_method})
  --algos METHOD ...          base clusterings to use for the consensus
  --final-algo METHOD         final CVC clustering, optionally +wcc (default: ${final_algo})
  --weighting-strategy N      ClusterMerger weighting strategy (default: ${weighting_strategy})
  --threshold X               ClusterMerger threshold (default: ${threshold})
  --weighted                  keep the ClusterMerger merged graph weighted (default: not set)
  --run-wcc                   run WCC after a pamcon consensus (default: not set)
  --merge-id ID               override the generated merge directory name
  --timeout DURATION          timeout for each stage (default: ${stage_timeout})

Examples:
  $0 examples/input/dnc.csv examples/output/dnc
  $0 examples/input/dnc.csv examples/output/dnc --merge-method ClusterMerger --algos flow-iter leiden-mod RTRex ikc-5
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 2 ]]; then
    usage
    exit 1
fi

shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --merge-method|--consensus|--method)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "Missing value for $1"
                usage
                exit 1
            fi
            merge_method="$2"
            shift 2
            ;;
        --algos|--methods|--input-algos|--ensemble-algos)
            METHODS=()
            methods_set=1
            shift
            while [[ $# -gt 0 && "$1" != --* ]]; do
                METHODS+=("$1")
                shift
            done
            if [[ ${#METHODS[@]} -eq 0 ]]; then
                echo "At least one method is required after --algos."
                usage
                exit 1
            fi
            ;;
        --final-algo)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "Missing value for --final-algo"
                usage
                exit 1
            fi
            final_algo="$2"
            shift 2
            ;;
        --weighting-strategy)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "Missing value for --weighting-strategy"
                usage
                exit 1
            fi
            weighting_strategy="$2"
            shift 2
            ;;
        --threshold)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "Missing value for --threshold"
                usage
                exit 1
            fi
            threshold="$2"
            shift 2
            ;;
        --weighted)
            unweight=0
            shift
            ;;
        --run-wcc)
            run_wcc=1
            shift
            ;;
        --merge-id)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "Missing value for --merge-id"
                usage
                exit 1
            fi
            merge_id="$2"
            shift 2
            ;;
        --timeout)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "Missing value for --timeout"
                usage
                exit 1
            fi
            stage_timeout="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

case "${merge_method}" in
    ClusterMerger)
        if [[ "${methods_set}" -eq 0 ]]; then
            METHODS=(flow-iter leiden-mod RTRex ikc-5)
        fi
        ;;
    pamcon)
        if [[ "${methods_set}" -eq 0 ]]; then
            METHODS=(leiden-mod leiden-cpm-0.01+wcc)
        fi
        ;;
    *)
        echo "Unknown merge method: ${merge_method}. Expected ClusterMerger or pamcon."
        usage
        exit 1
        ;;
esac

resolve_path() {
    local path=$1
    case "${path}" in
        /*) echo "${path}" ;;
        *) echo "${INVOKE_DIR}/${path}" ;;
    esac
}

edgelist="$(resolve_path "${edgelist}")"
out_root="$(resolve_path "${out_root}")"
flow_iter_bin="$(resolve_path "${flow_iter_bin}")"

if [[ ! -x "${cluster_merger_bin}" && -x "${CVC_ROOT}/externals/ClusterMerger/cluster_merger" ]]; then
    cluster_merger_bin="${CVC_ROOT}/externals/ClusterMerger/cluster_merger"
elif [[ ! -x "${cluster_merger_bin}" && -x "${CVC_ROOT}/externals/ClusterMerger/build/bin/cluster_merger" ]]; then
    cluster_merger_bin="${CVC_ROOT}/externals/ClusterMerger/build/bin/cluster_merger"
fi

if [[ ! -x "${rtrex_bin}" && -x "${CVC_ROOT}/externals/amazon-RTRExtractor/RTRex/clustering/RTRex" ]]; then
    rtrex_bin="${CVC_ROOT}/externals/amazon-RTRExtractor/RTRex/clustering/RTRex"
fi

if [[ -z "${wcc_bin}" ]]; then
    if [[ -x "${CVC_ROOT}/bin/constrained_clustering" ]]; then
        wcc_bin="${CVC_ROOT}/bin/constrained_clustering"
    elif [[ -x "${CVC_ROOT}/externals/constrained-clustering/build/bin/constrained_clustering" ]]; then
        wcc_bin="${CVC_ROOT}/externals/constrained-clustering/build/bin/constrained_clustering"
    elif [[ -x "${CVC_ROOT}/externals/constrained-clustering/constrained_clustering" ]]; then
        wcc_bin="${CVC_ROOT}/externals/constrained-clustering/constrained_clustering"
    else
        wcc_bin="constrained_clustering"
    fi
fi

if [[ ! -f "${edgelist}" ]]; then
    echo "Error: Edgelist file ${edgelist} not found."
    exit 1
fi

if [[ -n "${CONDA_ENV:-}" ]]; then
    if [[ -z "${CONDA_BIN:-}" ]]; then
        if command -v conda >/dev/null 2>&1; then
            CONDA_BIN="$(command -v conda)"
        elif [[ -x /u/vltanh/miniconda3/bin/conda ]]; then
            CONDA_BIN="/u/vltanh/miniconda3/bin/conda"
        else
            echo "Could not find conda. Set CONDA_BIN=/path/to/conda or unset CONDA_ENV." >&2
            exit 1
        fi
    fi
    PYTHON_CMD=("${CONDA_BIN}" run -n "${CONDA_ENV}" python)
fi

mkdir -p "${out_root}/clusterings" "${out_root}/merge"

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

normalize_method() {
    local method=$1
    local base

    if [[ "${method}" == *+wcc ]]; then
        base="$(normalize_method "${method%+wcc}")"
        echo "${base}+wcc"
        return
    fi

    case "${method}" in
        dsc-flow-iter) echo "flow-iter" ;;
        rtrex) echo "RTRex" ;;
        *) echo "${method}" ;;
    esac
}

requires_flow_iter() {
    local method
    local norm
    local base

    for method in "${METHODS[@]}"; do
        norm="$(normalize_method "${method}")"
        base="${norm%+wcc}"
        if [[ "${base}" == "flow-iter" || "${base}" == flow-iter-* ]]; then
            return 0
        fi
    done

    if [[ "${merge_method}" == "ClusterMerger" ]]; then
        norm="$(normalize_method "${final_algo}")"
        base="${norm%+wcc}"
        if [[ "${base}" == "flow-iter" || "${base}" == flow-iter-* ]]; then
            return 0
        fi
    fi

    return 1
}

sanitize_id() {
    local value=$1
    value="${value//+wcc/wcc}"
    value="${value//[^A-Za-z0-9]/}"
    echo "${value}"
}

method_alias() {
    local method
    method="$(normalize_method "$1")"

    case "${method}" in
        flow-iter) echo "f" ;;
        leiden-mod) echo "m" ;;
        RTRex) echo "r" ;;
        ikc-5) echo "k" ;;
        leiden-cpm-0.01+wcc) echo "c" ;;
        leiden-cpm-0.01) echo "c'" ;;
        infomap) echo "i" ;;
        *) sanitize_id "${method}" ;;
    esac
}

numeric_equal() {
    local lhs=$1
    local rhs=$2

    awk -v lhs="${lhs}" -v rhs="${rhs}" '
        function numeric(value) {
            return value ~ /^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/
        }
        BEGIN {
            if (!numeric(lhs) || !numeric(rhs)) {
                exit 1
            }
            diff = lhs - rhs
            if (diff < 0) {
                diff = -diff
            }
            exit(diff <= 1e-9 ? 0 : 1)
        }
    '
}

cluster_merger_alias() {
    local voter_count=${#METHODS[@]}
    local majority_threshold=$(((voter_count + 1) / 2))
    local strategy_id
    local threshold_id

    if [[ "${weighting_strategy}" == "0" ]] && numeric_equal "${threshold}" "0.5"; then
        echo "cvc"
        return
    fi

    if [[ "${weighting_strategy}" == "1" ]] && numeric_equal "${threshold}" "${majority_threshold}"; then
        echo "fvc"
        return
    fi

    strategy_id="$(sanitize_id "${weighting_strategy}")"
    threshold_id="$(sanitize_id "${threshold}")"
    echo "ws${strategy_id}t${threshold_id}"
}

combo_alias() {
    local method
    local alias=""

    for method in "$@"; do
        alias+="$(method_alias "${method}")"
    done
    echo "${alias}"
}

stage_done() {
    local dir=$1
    local output=$2

    if [[ -f "${output}" ]]; then
        [[ -f "${dir}/done" ]] || touch "${dir}/done"
        return 0
    fi
    return 1
}

run_plain_clustering() {
    local method
    local input_edge=$2
    local out_dir=$3
    local weighted=${4:-0}
    local command=()
    local k_val=""
    local resolution=""
    local flow_threshold=""
    local weight_args=()

    method="$(normalize_method "$1")"
    mkdir -p "${out_dir}"

    if stage_done "${out_dir}" "${out_dir}/com.csv"; then
        echo "[$(timestamp)] ${method} already done."
        return
    fi

    if [[ "${weighted}" -eq 1 ]]; then
        weight_args=(--weighted)
    fi

    case "${method}" in
        flow-iter)
            command=("${flow_iter_bin}" "${input_edge}" "${out_dir}/com.csv" "${out_dir}/density.csv")
            ;;
        flow-iter-*)
            flow_threshold="${method#flow-iter-}"
            command=("${flow_iter_bin}" "${input_edge}" "${out_dir}/com.csv" "${out_dir}/density.csv" "${flow_threshold}")
            ;;
        leiden-mod)
            command=("${PYTHON_CMD[@]}" "${METHOD_SCRIPT_DIR}/run_leiden.py" "${weight_args[@]}" --edgelist "${input_edge}" --output-directory "${out_dir}" --model mod)
            ;;
        leiden-cpm-*)
            resolution="${method#leiden-cpm-}"
            command=("${PYTHON_CMD[@]}" "${METHOD_SCRIPT_DIR}/run_leiden.py" "${weight_args[@]}" --edgelist "${input_edge}" --output-directory "${out_dir}" --model cpm --resolution "${resolution}")
            ;;
        RTRex)
            command=(env "RTREX_BIN=${rtrex_bin}" "${PYTHON_CMD[@]}" "${METHOD_SCRIPT_DIR}/run_RTRex.py" --edgelist "${input_edge}" --output-directory "${out_dir}")
            ;;
        ikc-*)
            k_val="${method#ikc-}"
            command=("${PYTHON_CMD[@]}" "${METHOD_SCRIPT_DIR}/run_ikc.py" --edgelist "${input_edge}" --output-directory "${out_dir}" --kvalue "${k_val}")
            ;;
        infomap)
            command=("${PYTHON_CMD[@]}" "${METHOD_SCRIPT_DIR}/run_infomap.py" --edgelist "${input_edge}" --output-directory "${out_dir}")
            ;;
        *)
            echo "Error: Unknown method '${method}'."
            exit 1
            ;;
    esac

    echo "[$(timestamp)] Running ${method}..."
    { timeout "${stage_timeout}" /usr/bin/time -v "${command[@]}"; } 1> "${out_dir}/output.log" 2> "${out_dir}/error.log"

    if [[ ! -f "${out_dir}/com.csv" ]]; then
        echo "Error: ${method} did not produce ${out_dir}/com.csv"
        exit 1
    fi

    touch "${out_dir}/done"
}

run_wcc_stage() {
    local input_edge=$1
    local input_com=$2
    local out_dir=$3
    local label=$4
    local stdout_log="${out_dir}/output.log"
    local stderr_log="${out_dir}/error.log"

    mkdir -p "${out_dir}"
    if stage_done "${out_dir}" "${out_dir}/com.csv"; then
        echo "[$(timestamp)] ${label} already done."
        return
    fi

    if [[ -f "${out_dir}/edge.csv" ]]; then
        stdout_log="${out_dir}/wcc_output.log"
        stderr_log="${out_dir}/wcc_error.log"
    fi

    echo "[$(timestamp)] Running WCC for ${label}..."
    { timeout "${stage_timeout}" /usr/bin/time -v "${wcc_bin}" \
        MincutOnly \
        --connectedness-criterion "1log_10(n)" \
        --edgelist "${input_edge}" \
        --existing-clustering "${input_com}" \
        --num-processors 1 \
        --output-file "${out_dir}/com.csv" \
        --log-file "${out_dir}/wcc.log" \
        --log-level 1; } 1> "${stdout_log}" 2> "${stderr_log}"

    if [[ ! -f "${out_dir}/com.csv" ]]; then
        echo "Error: WCC did not produce ${out_dir}/com.csv"
        exit 1
    fi

    touch "${out_dir}/done"
}

run_method() {
    local method
    local out_dir
    local base_method
    local base_dir

    method="$(normalize_method "$1")"
    out_dir="${out_root}/clusterings/${method}"

    if [[ "${method}" == *+wcc ]]; then
        base_method="${method%+wcc}"
        base_dir="${out_root}/clusterings/${base_method}"
        run_plain_clustering "${base_method}" "${edgelist}" "${base_dir}"
        run_wcc_stage "${edgelist}" "${base_dir}/com.csv" "${out_dir}" "${method}"
    else
        run_plain_clustering "${method}" "${edgelist}" "${out_dir}"
    fi

    METHOD_COM="${out_dir}/com.csv"
}

build_cluster_files() {
    local method
    cluster_files=()

    for method in "${METHODS[@]}"; do
        run_method "${method}"
        cluster_files+=("${METHOD_COM}")
    done
}

run_pamcon() {
    local out_dir
    local out_wcc_dir

    build_cluster_files

    if [[ -z "${merge_id}" ]]; then
        merge_id="$(combo_alias "${METHODS[@]}")-pamcon"
    fi
    out_dir="${out_root}/merge/${merge_id}"
    mkdir -p "${out_dir}"

    if ! stage_done "${out_dir}" "${out_dir}/com.csv"; then
        printf "%s\n" "${cluster_files[@]}" > "${out_dir}/clustering_list.txt"

        echo "[$(timestamp)] Running pamcon into ${out_dir}..."
        { timeout "${stage_timeout}" /usr/bin/time -v "${PYTHON_CMD[@]}" "${HELPER_SCRIPT_DIR}/run_pamcon.py" \
            --graph "${edgelist}" \
            --clusters "${cluster_files[@]}" \
            --bin "${pamcon_bin}" \
            --output-dir "${out_dir}" \
            --out-prefix com \
            --stage-prefix input_cluster; } 1> "${out_dir}/output.log" 2> "${out_dir}/error.log"

        if [[ ! -f "${out_dir}/com.csv" ]]; then
            echo "Error: pamcon did not produce ${out_dir}/com.csv"
            exit 1
        fi
        touch "${out_dir}/done"
    fi

    if [[ "${run_wcc}" -eq 1 ]]; then
        out_wcc_dir="${out_root}/merge/${merge_id}+wcc"
        run_wcc_stage "${edgelist}" "${out_dir}/com.csv" "${out_wcc_dir}" "${merge_id}+wcc"
    fi
}

run_cvc() {
    local out_dir
    local merged_dir
    local unweighted_dir
    local merged_edge
    local final_edge
    local final_norm
    local final_base
    local final_dir
    local final_wcc_dir
    local completion_file
    local cluster_merger_id
    local final_weighted=0

    build_cluster_files

    final_norm="$(normalize_method "${final_algo}")"
    if [[ "${run_wcc}" -eq 1 && "${final_norm}" != *+wcc ]]; then
        final_norm="${final_norm}+wcc"
    fi
    final_base="${final_norm%+wcc}"

    if [[ -z "${merge_id}" ]]; then
        cluster_merger_id="$(cluster_merger_alias)"
        merge_id="$(combo_alias "${METHODS[@]}")$(method_alias "${final_norm}")-${cluster_merger_id}"
    fi

    out_dir="${out_root}/merge/${merge_id}"
    merged_dir="${out_dir}/merged"
    unweighted_dir="${out_dir}/unweighted"
    final_dir="${out_dir}/final"
    final_wcc_dir="${out_dir}/final+wcc"
    merged_edge="${merged_dir}/edge.csv"
    mkdir -p "${out_dir}" "${merged_dir}"

    if [[ "${final_norm}" == *+wcc ]]; then
        completion_file="${final_wcc_dir}/com.csv"
    else
        completion_file="${final_dir}/com.csv"
    fi

    if stage_done "${out_dir}" "${completion_file}"; then
        echo "[$(timestamp)] ${merge_id} already done."
        return
    fi

    if ! stage_done "${merged_dir}" "${merged_edge}"; then
        printf "%s\n" "${cluster_files[@]}" > "${merged_dir}/clustering_list.txt"

        echo "[$(timestamp)] Running CVC merge into ${merged_dir}..."
        { timeout "${stage_timeout}" /usr/bin/time -v "${cluster_merger_bin}" \
            Weighted \
            --edgelist "${edgelist}" \
            --clustering-list "${merged_dir}/clustering_list.txt" \
            --weighting-strategy "${weighting_strategy}" \
            --threshold "${threshold}" \
            --num-processors 1 \
            --output-file "" \
            --output-weighted-graph "${merged_edge}" \
            --log-file "${merged_dir}/run.log" \
            --log-level 1; } 1> "${merged_dir}/output.log" 2> "${merged_dir}/error.log"

        [[ -f "${merged_edge}" ]] && touch "${merged_dir}/done"
    fi

    if [[ ! -f "${merged_edge}" ]]; then
        echo "Error: CVC merge did not produce ${merged_edge}"
        exit 1
    fi

    final_edge="${merged_edge}"
    if [[ "${unweight}" -eq 1 ]]; then
        mkdir -p "${unweighted_dir}"
        final_edge="${unweighted_dir}/edge.csv"
        if ! stage_done "${unweighted_dir}" "${final_edge}"; then
            echo "[$(timestamp)] Unweighting CVC merged graph..."
            { timeout "${stage_timeout}" /usr/bin/time -v "${PYTHON_CMD[@]}" "${HELPER_SCRIPT_DIR}/unweight.py" \
                --input-network "${merged_edge}" \
                --output-network "${final_edge}"; } 1> "${unweighted_dir}/output.log" 2> "${unweighted_dir}/error.log"

            [[ -f "${final_edge}" ]] && touch "${unweighted_dir}/done"
        fi

        if [[ ! -f "${final_edge}" ]]; then
            echo "Error: Unweighting did not produce ${final_edge}"
            exit 1
        fi
    else
        final_weighted=1
    fi

    run_plain_clustering "${final_base}" "${final_edge}" "${final_dir}" "${final_weighted}"

    if [[ "${final_norm}" == *+wcc ]]; then
        run_wcc_stage "${final_edge}" "${final_dir}/com.csv" "${final_wcc_dir}" "${merge_id}"
    else
        stage_done "${out_dir}" "${final_dir}/com.csv" >/dev/null
    fi

    stage_done "${out_dir}" "${completion_file}" >/dev/null
}

echo "[$(timestamp)] Pipeline root: ${out_root}"
if requires_flow_iter; then
    if [[ ! -x "${flow_iter_bin}" ]]; then
        echo "Error: flow-iter binary not found or not executable: ${flow_iter_bin}" >&2
        echo "Build/copy it to bin/flow-iter." >&2
        exit 1
    fi
    echo "[$(timestamp)] Flow-Iter binary: ${flow_iter_bin}"
fi
echo "[$(timestamp)] Merge method: ${merge_method}"
echo "[$(timestamp)] Methods: ${METHODS[*]}"

if [[ "${merge_method}" == "pamcon" ]]; then
    run_pamcon
else
    run_cvc
fi

echo "[$(timestamp)] Pipeline finished successfully."
