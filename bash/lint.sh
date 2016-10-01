function lint() {

  case "$1" in
    go)
      filewatcher -r '**/*.go' 'out=$(golint $FILENAME); if [ -z "$out" ]; then echo "\\033[0;32mAll Good\\033[0m"; else echo "\\033[0;31m$out\\033[0m"; fi';;
  esac

  # filewatcher -s -r '**/*.rb **/*.js **/*scss' 'echo $FILENAME; ext=${FILENAME##*\.}; case "$ext" in rb) rubocop $FILENAME;; js) eslint $FILENAME;; scss) scss-lint $FILENAME;;esac'
}
