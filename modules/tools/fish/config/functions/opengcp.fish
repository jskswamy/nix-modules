#!/usr/bin/env fish

function opengcp
    set project (gcloud projects list | rg -v PROJECT_ID | awk '{print $1}' | sort | fzf --reverse --height 20)
    if set -q project
        open "https://console.cloud.google.com/home/dashboard?project=$project"
    end
end
