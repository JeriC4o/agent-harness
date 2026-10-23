# Sourced, never executed, by the result-masking command in hooks/hooks.json and by
# hooks/lib/gate-record.sh, so the gate a hook refuses and the gate it records are one
# vocabulary. It is sourced by whatever shell runs an inline hook, dash included, so it
# must stay POSIX: a `.` of a file that does not parse ends that shell before any
# fail-open guard is reached.
#
# G  a gate at command position: a build or lint tool, a shell running a script whose
#    path token carries test/check/lint/verify, or jq with its exit-status flag.
# B  a shell running a .sh file or -n; two of them joined with && are refused.
# L  a gate inside a loop body.
G='(^|[;&|(`])[[:space:]]*((make|cargo|go|npm|pnpm|yarn|gradle|\./gradlew|mvn|pytest|shellcheck|ruff|eslint|'\
'ktlint)[[:space:]]|(bash|sh|zsh)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*[^[:space:]|;&]*(test|check|lint|'\
'verify)[^[:space:]|;&]*\.(sh|bash)|jq[[:space:]]+(-[A-Za-z]*e[A-Za-z]*|--exit-status)[[:space:]])'
B='(^|[;&|(`])[[:space:]]*(bash|sh|zsh)[[:space:]]+(-n[[:space:]]|[^;&|]*\.(sh|bash))'
L='(make|cargo|go|npm|pnpm|yarn|gradle|\./gradlew|mvn|pytest|shellcheck|ruff|eslint|ktlint)[[:space:]]|(bash|sh|'\
'zsh)[[:space:]]+(-n[[:space:]]|[^;&|]*\.(sh|bash)|[^;&|]*\$)'
