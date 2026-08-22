_my_tool_completions() {
  local cur path word next_path words i
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  path=""
  i=1
  while [ "$i" -lt "$COMP_CWORD" ]; do
    word="${COMP_WORDS[$i]}"
    next_path=""
    case "$path:$word" in
      ":status") next_path="status" ;;
    esac
    if [ -z "$next_path" ]; then
      break
    fi
    path="$next_path"
    i=$((i + 1))
  done

  words=""
  case "$path" in
    "") words="status" ;;
  esac

  COMPREPLY=($(compgen -W "$words" -- "$cur"))
}
complete -F _my_tool_completions my_tool
