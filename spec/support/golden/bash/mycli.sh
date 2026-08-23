_mycli_completions() {
  local cur prev path word next_path words i
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev=""
  if [ "$COMP_CWORD" -gt 0 ]; then
    prev="${COMP_WORDS[$((COMP_CWORD - 1))]}"
  fi
  path=""
  i=1
  while [ "$i" -lt "$COMP_CWORD" ]; do
    word="${COMP_WORDS[$i]}"
    next_path=""
    case "$path:$word" in
      ":version") next_path="version" ;;
      ":deploy") next_path="deploy" ;;
      ":db") next_path="db" ;;
      "db:migrate") next_path="db migrate" ;;
    esac
    if [ -z "$next_path" ]; then
      break
    fi
    path="$next_path"
    i=$((i + 1))
  done

  case "$path:$prev" in
    "version:--format") COMPREPLY=($(compgen -W "json plain" -- "$cur")); return ;;
  esac

  words=""
  case "$path" in
    "") words="version deploy db" ;;
    "version") words="--format" ;;
    "deploy") words="--force -f staging production" ;;
    "db") words="migrate --verbose -v" ;;
  esac

  COMPREPLY=($(compgen -W "$words" -- "$cur"))
  case "$path" in
    "db migrate") COMPREPLY+=($(compgen -f -- "$cur")) ;;
  esac
}
complete -F _mycli_completions mycli
