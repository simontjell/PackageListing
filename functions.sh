#!/bin/bash

vscode_extensions_html_table() {
  echo '<table border="1" cellpadding="4" cellspacing="0">'
  echo '  <tr><th>Name</th><th>Version</th><th>Link</th><th>Description</th></tr>'
  code --list-extensions --show-versions | while read extver; do
    ext="${extver%@*}"
    ver="${extver##*@}"
    # Hent metadata fra Marketplace API
    data=$(curl -s "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json;api-version=3.0-preview.1" \
      --data-binary "{\"filters\":[{\"criteria\":[{\"filterType\":7,\"value\":\"$ext\"}]}],\"flags\":914}" )
    name=$(echo "$data" | grep -oP '"displayName":"\K[^"]+')
    desc=$(echo "$data" | grep -oP '"shortDescription":"\K[^"]+')
    url="https://marketplace.visualstudio.com/items?itemName=$ext"
    echo "  <tr><td>${name:-$ext}</td><td>${ver}</td><td><a href=\"$url\">$ext</a></td><td>${desc:-}</td></tr>"
  done
  echo '</table>'
}

apt_packages_html_table() {
  echo '<table border="1" cellpadding="4" cellspacing="0">'
  echo '  <tr><th>Name</th><th>Version</th><th>Description</th></tr>'
  # Only use the first line of the description (short description)
  dpkg-query -W -f='${Package}\t${Version}\t${Description}\n' | while IFS=$'\t' read -r name version desc; do
    # Only print if name and version are not empty
    if [[ -n "$name" && -n "$version" ]]; then
      # Only use the first sentence/line of the description
      shortdesc=$(echo "$desc" | head -n1)
      echo "  <tr><td>${name}</td><td>${version}</td><td>${shortdesc}</td></tr>"
    fi
  done
  echo '</table>'
}

nuget_packages_html_table() {
  local project_path="$1"
  if [[ -z "$project_path" ]]; then
    echo "Usage: nuget_packages_html_table <path-to-csproj-or-sln>"
    return 1
  fi
  echo '<table border="1" cellpadding="4" cellspacing="0">'
  echo '  <tr><th>Name</th><th>Version</th><th>Description</th></tr>'
  dotnet list "$project_path" package --include-transitive --format json | \
    jq -r '.projects[].frameworks[].topLevelPackages[]? | [.id, .resolvedVersion] | @tsv' | \
    sort -u | tr -d '\r' | while IFS=$'\t' read -r name version; do
      if [[ -n "$name" && -n "$version" ]]; then
        json=$(curl -s "https://api.nuget.org/v3/registration5-semver1/${name,,}/index.json")
        if echo "$json" | jq . >/dev/null 2>&1; then
          desc=$(echo "$json" | jq -r '.items[0].items[0].catalogEntry.description // ""' | head -1)
        else
          desc=""
        fi
        desc=$(echo "$desc" | tr '\n' ' ' | tr '\t' ' ' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        echo "<tr><td>${name}</td><td>${version}</td><td>${desc}</td></tr>"
      fi
    done
  echo '</table>'
}

