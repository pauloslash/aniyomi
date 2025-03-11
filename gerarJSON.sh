#!/bin/bash

# Lista de URLs dos JSONs
URLS=(
    "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
    "https://raw.githubusercontent.com/almightyhak/aniyomi-anime-repo/main/index.min.json"
)

# Diretório de saída
OUTPUT_DIR="" #"outputs/"
if [[ "$VARIAVEL" == */* ]]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Listas de nomes a serem modificados
NAMES_Y=("Pirulito Rosa")
NAMES_X=("Example1" "Example2" "Example3")  # Substitua pelos nomes desejados

# Baixar e processar os arquivos JSON
for URL in "${URLS[@]}"; do
    # Extrai o nome do usuário do GitHub da URL
    USERNAME=$(echo "$URL" | sed -E 's|https://raw.githubusercontent.com/([^/]+)/.*|\1|')

    # Criar diretório para o usuário
    USER_DIR="${OUTPUT_DIR}${USERNAME}"
    mkdir -p "$USER_DIR"

    # Baixar JSON temporariamente
    TEMP_FILE=$(mktemp)
    curl -s -H "Cache-Control: no-cache, no-store, must-revalidate" -H "Pragma: no-cache" -H "Expires: 0" "$URL" -o "$TEMP_FILE"

    # Processar JSON e salvar no diretório do usuário
    jq --argjson names_y "$(printf '%s\n' "${NAMES_Y[@]}" | jq -R . | jq -s .)" \
       --argjson names_x "$(printf '%s\n' "${NAMES_X[@]}" | jq -R . | jq -s .)" '
      reduce .[] as $item ({}; 
        .[$item.name] += [$item]
      ) 
      | to_entries
      | map(
          .key as $key
          | .value as $values
          | if ($values | length) > 1 then
              $values[0] as $first
              | [ $values[].sources[].id ] as $all_ids
              | $all_ids[0] as $base_ids
              | [ $values[].pkg ] as $all_pkgs
              | $all_pkgs[0] as $base_pkg
              | if ($all_ids | all( . == $base_ids )) and ($all_pkgs | all( . == $base_pkg )) then
                  $values
              else
                  $values | map(
                    if .pkg then 
                      .name += " (" + (.pkg | split(".") | if length > 1 then .[1] else "unknown" end) + ")"
                    else 
                      .
                    end
                  )
              end
          else
              $values
          end
      )
      | flatten
      | map(
        . as $parent |
        ($parent.name | split(": ") | if length > 1 then .[0] + ": " else "" end) as $prefix |
        ($parent.name | split(": ") | if length > 1 then .[1] else .[0] end) as $clean_name |

        if ([$clean_name] | inside($names_y)) and (.nsfw // 0) == 1 then
          .name = $prefix + "HY_" + $clean_name
        elif ([$clean_name] | inside($names_y)) then
          .name = $prefix + "Y_" + $clean_name
        elif ([$clean_name] | inside($names_x)) and (.nsfw // 0) == 1 then
          .name = $prefix + "HX_" + $clean_name
        elif ([$clean_name] | inside($names_x)) then
          .name = $prefix + "X_" + $clean_name
        elif (.nsfw // 0) == 1 then
          .name = $prefix + "H_" + $clean_name
        elif ($clean_name | test("yaoi"; "i")) then  # Nova regra: se "name" contém "yaoi", adiciona "Y_"
          .name = $prefix + "Y_" + $clean_name
        else .
        end
      )
    ' "$TEMP_FILE" > "$USER_DIR/index.min.json"

    # Remover arquivo temporário
    rm -f "$TEMP_FILE"
done

echo "✅ Arquivos JSON gerados dentro de '$OUTPUT_DIR' separados por usuário do GitHub!"
