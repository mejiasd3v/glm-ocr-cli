_ocr() {
  local cur prev words cword
  _init_completion || return

  local commands="parse install server status config env models stop logs doctor benchmark help version completion"

  if [[ $cword -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return
  fi

  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "$prev" in
    completion)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      return
      ;;
    parse|doctor)
      COMPREPLY=( $(compgen -f -- "$cur") )
      return
      ;;
    benchmark)
      COMPREPLY=( $(compgen -W "--models --cases --out-dir --port" -- "$cur") )
      return
      ;;
    --models)
      COMPREPLY=( $(compgen -W "bf16 8bit 6bit 5bit 4bit" -- "$cur") )
      return
      ;;
  esac

  case "${COMP_WORDS[1]}" in
    parse|doctor)
      COMPREPLY=( $(compgen -f -- "$cur") )
      ;;
    benchmark)
      COMPREPLY=( $(compgen -W "--models --cases --out-dir --port bf16 8bit 6bit 5bit 4bit" -- "$cur") )
      ;;
    completion)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      ;;
    *)
      COMPREPLY=( $(compgen -f -W "$commands" -- "$cur") )
      ;;
  esac
}

complete -F _ocr ocr
