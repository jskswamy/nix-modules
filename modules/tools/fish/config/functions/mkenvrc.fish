function mkenvrc --description 'Create source_up + layout venv .envrc here and allow it'
    if test -e .envrc
        echo "mkenvrc: .envrc already exists here" >&2
        return 1
    end
    printf 'source_up\nlayout venv\n' > .envrc
    direnv allow
end
