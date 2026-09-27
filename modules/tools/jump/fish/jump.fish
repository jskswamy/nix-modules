if status --is-interactive; and command -q jump
    source (jump shell fish | psub)
end
