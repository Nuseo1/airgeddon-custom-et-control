#!/usr/bin/env bash

#Global shellcheck disabled warnings
#shellcheck disable=SC2034,SC2154

plugin_name="Manual Evil Twin Control"
plugin_description="Plugin, um BSSID, Kanal und ESSID für Evil Twin Angriffe manuell auszuwählen."
plugin_author="Nuseo1"

#Enabled 1 / Disabled 0 - Set this plugin as enabled - Default value 1
plugin_enabled=1

plugin_minimum_ag_affected_version="11.41"
plugin_maximum_ag_affected_version=""

plugin_distros_supported=("*")

# Globale Variablen für das Plugin
declare -gA custom_et_strings
declare -g custom_et_chosen_bssid=""
declare -g custom_et_chosen_essid=""

# -------------------------------------------------------------
# Zentrale Funktion: Abfrage-Menü (Läuft im Prehook)
# -------------------------------------------------------------
function _custom_et_interactive_prompt() {
    debug_print

    # Variablen bei jedem neuen Aufruf zurücksetzen
    custom_et_chosen_bssid=""
    custom_et_chosen_essid=""

    echo
    echo -e "${yellow_color}${custom_et_strings[${language},text_1]}${normal_color}"
    echo

    # --- 1. BSSID AUSWAHL ---
    echo -e "${cyan_color}${custom_et_strings[${language},text_2]}${normal_color}"
    echo -e "1. ${custom_et_strings[${language},text_3]} (${bssid})"
    echo -e "2. ${custom_et_strings[${language},text_4]}"
    echo -e "3. ${custom_et_strings[${language},text_5]}"
    read -rp "> " bssid_choice

    case "${bssid_choice}" in
        1)
            custom_et_chosen_bssid="${bssid}"
            echo -e "${green_color}${custom_et_strings[${language},text_6]} ${custom_et_chosen_bssid}${normal_color}"
            echo -e "${red_color}${custom_et_strings[${language},text_7]}${normal_color}"
            ;;
        2)
            echo -e "${green_color}${custom_et_strings[${language},text_8]}${normal_color}"
            read -rp "> " custom_bssid
            if [[ -n "${custom_bssid}" && "${custom_bssid}" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                custom_et_chosen_bssid="${custom_bssid}"
                echo -e "${green_color}${custom_et_strings[${language},text_9]} ${custom_et_chosen_bssid}${normal_color}"
            else
                echo -e "${red_color}${custom_et_strings[${language},text_10]}${normal_color}"
            fi
            ;;
        *)
            echo -e "${green_color}${custom_et_strings[${language},text_11]}${normal_color}"
            ;;
    esac

    # --- 2. KANAL AUSWAHL ---
    echo
    echo -e "${cyan_color}${custom_et_strings[${language},text_12]} ${channel}${normal_color}"
    echo -e "${cyan_color}${custom_et_strings[${language},text_12b]}${normal_color}"
    read -rp "> " custom_channel
    
    if [[ -n "${custom_channel}" && "${custom_channel}" =~ ^[0-9]+$ && "${custom_channel}" -gt 0 && "${custom_channel}" -le 196 ]]; then
        channel="${custom_channel}" # Die Kanal-Variable von airgeddon kann direkt überschrieben werden
        echo -e "${green_color}${custom_et_strings[${language},text_13]} ${channel}${normal_color}"
    else
        echo -e "${green_color}${custom_et_strings[${language},text_14]} ${channel}${normal_color}"
    fi

    # --- 3. ESSID AUSWAHL ---
    echo
    echo -e "${cyan_color}${custom_et_strings[${language},text_15]}${normal_color}"
    echo -e "1. ${custom_et_strings[${language},text_16]} (${essid})"
    echo -e "2. ${custom_et_strings[${language},text_17]}"
    echo -e "3. ${custom_et_strings[${language},text_18]}"
    read -rp "> " essid_choice

    case "${essid_choice}" in
        1)
            # Hängt das unsichtbare Leerzeichen an die originale ESSID an
            custom_et_chosen_essid=$(echo -e "${essid}\xE2\x80\x8B")
            echo -e "${green_color}${custom_et_strings[${language},text_19]} \"${essid}\" (mit Zero-Width Space)${normal_color}"
            ;;
        2)
            echo -e "${green_color}${custom_et_strings[${language},text_20]}${normal_color}"
            read -rp "> " custom_essid
            if [[ -n "${custom_essid}" ]]; then
                # Hängt das unsichtbare Leerzeichen an die selbst eingetippte ESSID an
                custom_et_chosen_essid=$(echo -e "${custom_essid}\xE2\x80\x8B")
                echo -e "${green_color}${custom_et_strings[${language},text_21]} \"${custom_essid}\" (mit Zero-Width Space)${normal_color}"
            else
                echo -e "${yellow_color}${custom_et_strings[${language},text_22]}${normal_color}"
            fi
            ;;
        *)
            echo -e "${green_color}${custom_et_strings[${language},text_23]}${normal_color}"
            ;;
    esac

    echo
    sleep 2
}

# -------------------------------------------------------------
# PREHOOKS (Vor der Konfigurationserstellung)
# -------------------------------------------------------------
function custom_et_control_prehook_set_hostapd_config() { _custom_et_interactive_prompt; }
function custom_et_control_prehook_set_hostapd_wpe_config() { _custom_et_interactive_prompt; }
function custom_et_control_prehook_set_hostapd_mana_config() { _custom_et_interactive_prompt; }

# -------------------------------------------------------------
# POSTHOOKS (Schreiben der Werte in die generierte Hostapd Config)
# -------------------------------------------------------------
function _apply_custom_et_config() {
    local target_config_file="${1}"

    if [[ -n "${custom_et_chosen_bssid}" ]]; then
        et_bssid="${custom_et_chosen_bssid}"
        sed -ri "s/^bssid=.*/bssid=${et_bssid}/" "${target_config_file}" 2> /dev/null
    fi

    if [[ -n "${custom_et_chosen_essid}" ]]; then
        et_essid="${custom_et_chosen_essid}"
        # Sicheres Ersetzen (Falls Sonderzeichen in der ESSID sind)
        local safe_essid
        safe_essid=$(echo "${et_essid}" | sed 's/|/\\|/g')
        sed -ri "s|^ssid=.*|ssid=${safe_essid}|" "${target_config_file}" 2> /dev/null
    fi
}

function custom_et_control_posthook_set_hostapd_config() { _apply_custom_et_config "${tmpdir}${hostapd_file}"; }
function custom_et_control_posthook_set_hostapd_wpe_config() { _apply_custom_et_config "${tmpdir}${hostapd_wpe_file}"; }
function custom_et_control_posthook_set_hostapd_mana_config() { _apply_custom_et_config "${tmpdir}${hostapd_mana_file}"; }

# -------------------------------------------------------------
# Sprach-Strings Initialisierung für ALLE airgeddon-Sprachen
# -------------------------------------------------------------
function custom_et_control_prehook_hookable_for_languages() {

    # === ENGLISH ===
    custom_et_strings["ENGLISH","text_1"]="Manual Evil Twin control:"
    custom_et_strings["ENGLISH","text_2"]="How should the BSSID for the Evil Twin be set?"
    custom_et_strings["ENGLISH","text_3"]="Use exact original BSSID"
    custom_et_strings["ENGLISH","text_4"]="Enter a completely new BSSID manually"
    custom_et_strings["ENGLISH","text_5"]="Use standard (slightly modified) Airgeddon BSSID (default)"
    custom_et_strings["ENGLISH","text_6"]="OK. Original BSSID will be used:"
    custom_et_strings["ENGLISH","text_7"]="Warning: This may cause instability in the network!"
    custom_et_strings["ENGLISH","text_8"]="Please enter the desired BSSID (format XX:XX:XX:XX:XX:XX):"
    custom_et_strings["ENGLISH","text_9"]="BSSID has been set to:"
    custom_et_strings["ENGLISH","text_10"]="Invalid format. Generating standard BSSID..."
    custom_et_strings["ENGLISH","text_11"]="OK. Standard Airgeddon BSSID will be used."
    custom_et_strings["ENGLISH","text_12"]="Current channel:"
    custom_et_strings["ENGLISH","text_12b"]="Enter a new channel (e.g. 1-165) or press Enter to keep it:"
    custom_et_strings["ENGLISH","text_13"]="Channel has been set to:"
    custom_et_strings["ENGLISH","text_14"]="Keeping standard channel:"
    custom_et_strings["ENGLISH","text_15"]="How should the ESSID (AP name) for the Evil Twin be set?"
    custom_et_strings["ENGLISH","text_16"]="Use exact original ESSID"
    custom_et_strings["ENGLISH","text_17"]="Enter a new ESSID manually"
    custom_et_strings["ENGLISH","text_18"]="Use standard (fake) Airgeddon ESSID (default)"
    custom_et_strings["ENGLISH","text_19"]="OK. Original ESSID will be used:"
    custom_et_strings["ENGLISH","text_20"]="Please enter the desired ESSID:"
    custom_et_strings["ENGLISH","text_21"]="ESSID has been set to:"
    custom_et_strings["ENGLISH","text_22"]="No input. Generating standard ESSID..."
    custom_et_strings["ENGLISH","text_23"]="OK. Standard Airgeddon ESSID will be used."

    # === SPANISH ===
    custom_et_strings["SPANISH","text_1"]="Control manual de Evil Twin:"
    custom_et_strings["SPANISH","text_2"]="¿Cómo se debe configurar el BSSID para el Evil Twin?"
    custom_et_strings["SPANISH","text_3"]="Usar el BSSID original exacto"
    custom_et_strings["SPANISH","text_4"]="Introducir un BSSID completamente nuevo manualmente"
    custom_et_strings["SPANISH","text_5"]="Usar BSSID estándar (ligeramente modificado) de Airgeddon (predeterminado)"
    custom_et_strings["SPANISH","text_6"]="OK. Se utilizará el BSSID original:"
    custom_et_strings["SPANISH","text_7"]="Advertencia: ¡Esto puede causar inestabilidad en la red!"
    custom_et_strings["SPANISH","text_8"]="Introduzca el BSSID deseado (formato XX:XX:XX:XX:XX:XX):"
    custom_et_strings["SPANISH","text_9"]="BSSID se ha configurado en:"
    custom_et_strings["SPANISH","text_10"]="Formato no válido. Generando BSSID estándar..."
    custom_et_strings["SPANISH","text_11"]="OK. Se utilizará el BSSID estándar de Airgeddon."
    custom_et_strings["SPANISH","text_12"]="Canal actual:"
    custom_et_strings["SPANISH","text_12b"]="Introduzca un nuevo canal (ej. 1-165) o presione Intro para mantenerlo:"
    custom_et_strings["SPANISH","text_13"]="El canal se configuró en:"
    custom_et_strings["SPANISH","text_14"]="Manteniendo el canal estándar:"
    custom_et_strings["SPANISH","text_15"]="¿Cómo se debe configurar el ESSID (nombre del AP) para el Evil Twin?"
    custom_et_strings["SPANISH","text_16"]="Usar el ESSID original exacto"
    custom_et_strings["SPANISH","text_17"]="Introducir un nuevo ESSID manualmente"
    custom_et_strings["SPANISH","text_18"]="Usar ESSID estándar (falso) de Airgeddon (predeterminado)"
    custom_et_strings["SPANISH","text_19"]="OK. Se utilizará el ESSID original:"
    custom_et_strings["SPANISH","text_20"]="Por favor, introduzca el ESSID deseado:"
    custom_et_strings["SPANISH","text_21"]="ESSID se ha configurado en:"
    custom_et_strings["SPANISH","text_22"]="Sin entrada. Generando ESSID estándar..."
    custom_et_strings["SPANISH","text_23"]="OK. Se utilizará el ESSID estándar de Airgeddon."

    # === FRENCH ===
    custom_et_strings["FRENCH","text_1"]="Contrôle manuel de Evil Twin :"
    custom_et_strings["FRENCH","text_2"]="Comment le BSSID pour le Evil Twin doit-il être défini ?"
    custom_et_strings["FRENCH","text_3"]="Utiliser le BSSID original exact"
    custom_et_strings["FRENCH","text_4"]="Entrer un BSSID complètement nouveau manuellement"
    custom_et_strings["FRENCH","text_5"]="Utiliser le BSSID standard (légèrement modifié) d'Airgeddon (par défaut)"
    custom_et_strings["FRENCH","text_6"]="OK. Le BSSID original sera utilisé :"
    custom_et_strings["FRENCH","text_7"]="Attention : Cela peut causer une instabilité dans le réseau !"
    custom_et_strings["FRENCH","text_8"]="Veuillez entrer le BSSID désiré (format XX:XX:XX:XX:XX:XX) :"
    custom_et_strings["FRENCH","text_9"]="Le BSSID a été défini sur :"
    custom_et_strings["FRENCH","text_10"]="Format invalide. Génération du BSSID standard..."
    custom_et_strings["FRENCH","text_11"]="OK. Le BSSID standard d'Airgeddon sera utilisé."
    custom_et_strings["FRENCH","text_12"]="Canal actuel :"
    custom_et_strings["FRENCH","text_12b"]="Entrez un nouveau canal (ex. 1-165) ou appuyez sur Entrée pour le conserver :"
    custom_et_strings["FRENCH","text_13"]="Le canal a été défini sur :"
    custom_et_strings["FRENCH","text_14"]="Conservation du canal standard :"
    custom_et_strings["FRENCH","text_15"]="Comment l'ESSID (nom de l'AP) pour le Evil Twin doit-il être défini ?"
    custom_et_strings["FRENCH","text_16"]="Utiliser l'ESSID original exact"
    custom_et_strings["FRENCH","text_17"]="Entrer un nouvel ESSID manuellement"
    custom_et_strings["FRENCH","text_18"]="Utiliser l'ESSID standard (faux) d'Airgeddon (par défaut)"
    custom_et_strings["FRENCH","text_19"]="OK. L'ESSID original sera utilisé :"
    custom_et_strings["FRENCH","text_20"]="Veuillez entrer l'ESSID désiré :"
    custom_et_strings["FRENCH","text_21"]="L'ESSID a été défini sur :"
    custom_et_strings["FRENCH","text_22"]="Aucune saisie. Génération de l'ESSID standard..."
    custom_et_strings["FRENCH","text_23"]="OK. L'ESSID standard d'Airgeddon sera utilisé."

    # === CATALAN ===
    custom_et_strings["CATALAN","text_1"]="Control manual d'Evil Twin:"
    custom_et_strings["CATALAN","text_2"]="Com s'ha de configurar el BSSID per a l'Evil Twin?"
    custom_et_strings["CATALAN","text_3"]="Utilitzeu el BSSID original exacte"
    custom_et_strings["CATALAN","text_4"]="Introduïu un BSSID completament nou manualment"
    custom_et_strings["CATALAN","text_5"]="Utilitzeu el BSSID estàndard (lleugerament modificat) d'Airgeddon (predeterminat)"
    custom_et_strings["CATALAN","text_6"]="D'acord. S'utilitzarà el BSSID original:"
    custom_et_strings["CATALAN","text_7"]="Advertència: Això pot causar inestabilitat a la xarxa!"
    custom_et_strings["CATALAN","text_8"]="Introduïu el BSSID desitjat (format XX:XX:XX:XX:XX:XX):"
    custom_et_strings["CATALAN","text_9"]="El BSSID s'ha configurat a:"
    custom_et_strings["CATALAN","text_10"]="Format no vàlid. Generant BSSID estàndard..."
    custom_et_strings["CATALAN","text_11"]="D'acord. S'utilitzarà el BSSID estàndard d'Airgeddon."
    custom_et_strings["CATALAN","text_12"]="Canal actual:"
    custom_et_strings["CATALAN","text_12b"]="Introduïu un nou canal (ex. 1-165) o premeu Intro per mantenir-lo:"
    custom_et_strings["CATALAN","text_13"]="El canal s'ha configurat a:"
    custom_et_strings["CATALAN","text_14"]="Mantenint el canal estàndard:"
    custom_et_strings["CATALAN","text_15"]="Com s'ha de configurar l'ESSID (nom AP) per a l'Evil Twin?"
    custom_et_strings["CATALAN","text_16"]="Utilitzeu l'ESSID original exacte"
    custom_et_strings["CATALAN","text_17"]="Introduïu un nou ESSID manualment"
    custom_et_strings["CATALAN","text_18"]="Utilitzeu l'ESSID estàndard (fals) d'Airgeddon (predeterminat)"
    custom_et_strings["CATALAN","text_19"]="D'acord. S'utilitzarà l'ESSID original:"
    custom_et_strings["CATALAN","text_20"]="Introduïu l'ESSID desitjat:"
    custom_et_strings["CATALAN","text_21"]="L'ESSID s'ha configurat a:"
    custom_et_strings["CATALAN","text_22"]="Sense entrada. Generant ESSID estàndard..."
    custom_et_strings["CATALAN","text_23"]="D'acord. S'utilitzarà l'ESSID estàndard d'Airgeddon."

    # === PORTUGUESE ===
    custom_et_strings["PORTUGUESE","text_1"]="Controle manual do Evil Twin:"
    custom_et_strings["PORTUGUESE","text_2"]="Como o BSSID para o Evil Twin deve ser configurado?"
    custom_et_strings["PORTUGUESE","text_3"]="Usar o BSSID original exato"
    custom_et_strings["PORTUGUESE","text_4"]="Inserir um BSSID completamente novo manualmente"
    custom_et_strings["PORTUGUESE","text_5"]="Usar o BSSID padrão (levemente modificado) do Airgeddon (padrão)"
    custom_et_strings["PORTUGUESE","text_6"]="OK. O BSSID original será usado:"
    custom_et_strings["PORTUGUESE","text_7"]="Aviso: Isso pode causar instabilidade na rede!"
    custom_et_strings["PORTUGUESE","text_8"]="Insira o BSSID desejado (formato XX:XX:XX:XX:XX:XX):"
    custom_et_strings["PORTUGUESE","text_9"]="O BSSID foi definido para:"
    custom_et_strings["PORTUGUESE","text_10"]="Formato inválido. Gerando BSSID padrão..."
    custom_et_strings["PORTUGUESE","text_11"]="OK. O BSSID padrão do Airgeddon será usado."
    custom_et_strings["PORTUGUESE","text_12"]="Canal atual:"
    custom_et_strings["PORTUGUESE","text_12b"]="Digite um novo canal (ex. 1-165) ou pressione Enter para mantê-lo:"
    custom_et_strings["PORTUGUESE","text_13"]="O canal foi definido para:"
    custom_et_strings["PORTUGUESE","text_14"]="Mantendo o canal padrão:"
    custom_et_strings["PORTUGUESE","text_15"]="Como o ESSID (nome do AP) para o Evil Twin deve ser configurado?"
    custom_et_strings["PORTUGUESE","text_16"]="Usar o ESSID original exato"
    custom_et_strings["PORTUGUESE","text_17"]="Inserir um novo ESSID manualmente"
    custom_et_strings["PORTUGUESE","text_18"]="Usar o ESSID padrão (falso) do Airgeddon (padrão)"
    custom_et_strings["PORTUGUESE","text_19"]="OK. O ESSID original será usado:"
    custom_et_strings["PORTUGUESE","text_20"]="Por favor, insira o ESSID desejado:"
    custom_et_strings["PORTUGUESE","text_21"]="O ESSID foi definido para:"
    custom_et_strings["PORTUGUESE","text_22"]="Nenhuma entrada. Gerando ESSID padrão..."
    custom_et_strings["PORTUGUESE","text_23"]="OK. O ESSID padrão do Airgeddon será usado."

    # === RUSSIAN ===
    custom_et_strings["RUSSIAN","text_1"]="Ручное управление Evil Twin:"
    custom_et_strings["RUSSIAN","text_2"]="Как должен быть установлен BSSID для Evil Twin?"
    custom_et_strings["RUSSIAN","text_3"]="Использовать точный исходный BSSID"
    custom_et_strings["RUSSIAN","text_4"]="Ввести совершенно новый BSSID вручную"
    custom_et_strings["RUSSIAN","text_5"]="Использовать стандартный (слегка измененный) BSSID Airgeddon (по умолчанию)"
    custom_et_strings["RUSSIAN","text_6"]="ОК. Будет использован исходный BSSID:"
    custom_et_strings["RUSSIAN","text_7"]="Предупреждение: Это может вызвать нестабильность в сети!"
    custom_et_strings["RUSSIAN","text_8"]="Пожалуйста, введите желаемый BSSID (формат XX:XX:XX:XX:XX:XX):"
    custom_et_strings["RUSSIAN","text_9"]="BSSID был установлен на:"
    custom_et_strings["RUSSIAN","text_10"]="Неверный формат. Генерация стандартного BSSID..."
    custom_et_strings["RUSSIAN","text_11"]="ОК. Будет использован стандартный BSSID Airgeddon."
    custom_et_strings["RUSSIAN","text_12"]="Текущий канал:"
    custom_et_strings["RUSSIAN","text_12b"]="Введите новый канал (например, 1-165) или нажмите Enter, чтобы оставить его:"
    custom_et_strings["RUSSIAN","text_13"]="Канал установлен на:"
    custom_et_strings["RUSSIAN","text_14"]="Сохранение стандартного канала:"
    custom_et_strings["RUSSIAN","text_15"]="Как должен быть установлен ESSID (имя AP) для Evil Twin?"
    custom_et_strings["RUSSIAN","text_16"]="Использовать точный исходный ESSID"
    custom_et_strings["RUSSIAN","text_17"]="Ввести новый ESSID вручную"
    custom_et_strings["RUSSIAN","text_18"]="Использовать стандартный (поддельный) ESSID Airgeddon (по умолчанию)"
    custom_et_strings["RUSSIAN","text_19"]="ОК. Будет использован исходный ESSID:"
    custom_et_strings["RUSSIAN","text_20"]="Пожалуйста, введите желаемый ESSID:"
    custom_et_strings["RUSSIAN","text_21"]="ESSID был установлен на:"
    custom_et_strings["RUSSIAN","text_22"]="Нет ввода. Генерация стандартного ESSID..."
    custom_et_strings["RUSSIAN","text_23"]="ОК. Будет использован стандартный ESSID Airgeddon."

    # === GREEK ===
    custom_et_strings["GREEK","text_1"]="Χειροκίνητος έλεγχος Evil Twin:"
    custom_et_strings["GREEK","text_2"]="Πώς πρέπει να ρυθμιστεί το BSSID για το Evil Twin;"
    custom_et_strings["GREEK","text_3"]="Χρησιμοποιήστε το ακριβές αρχικό BSSID"
    custom_et_strings["GREEK","text_4"]="Εισαγάγετε ένα εντελώς νέο BSSID χειροκίνητα"
    custom_et_strings["GREEK","text_5"]="Χρησιμοποιήστε το τυπικό (ελαφρώς τροποποιημένο) BSSID του Airgeddon (προεπιλογή)"
    custom_et_strings["GREEK","text_6"]="OK. Το αρχικό BSSID θα χρησιμοποιηθεί:"
    custom_et_strings["GREEK","text_7"]="Προειδοποίηση: Αυτό μπορεί να προκαλέσει αστάθεια στο δίκτυο!"
    custom_et_strings["GREEK","text_8"]="Παρακαλώ εισαγάγετε το επιθυμητό BSSID (μορφή XX:XX:XX:XX:XX:XX):"
    custom_et_strings["GREEK","text_9"]="Το BSSID έχει οριστεί σε:"
    custom_et_strings["GREEK","text_10"]="Μη έγκυρη μορφή. Δημιουργία τυπικού BSSID..."
    custom_et_strings["GREEK","text_11"]="OK. Θα χρησιμοποιηθεί το τυπικό BSSID του Airgeddon."
    custom_et_strings["GREEK","text_12"]="Τρέχον κανάλι:"
    custom_et_strings["GREEK","text_12b"]="Εισαγάγετε νέο κανάλι (π.χ. 1-165) ή πατήστε Enter για να το κρατήσετε:"
    custom_et_strings["GREEK","text_13"]="Το κανάλι έχει οριστεί σε:"
    custom_et_strings["GREEK","text_14"]="Διατήρηση τυπικού καναλιού:"
    custom_et_strings["GREEK","text_15"]="Πώς πρέπει να ρυθμιστεί το ESSID (όνομα AP) για το Evil Twin;"
    custom_et_strings["GREEK","text_16"]="Χρησιμοποιήστε το ακριβές αρχικό ESSID"
    custom_et_strings["GREEK","text_17"]="Εισαγάγετε ένα νέο ESSID χειροκίνητα"
    custom_et_strings["GREEK","text_18"]="Χρησιμοποιήστε το τυπικό (ψεύτικο) ESSID του Airgeddon (προεπιλογή)"
    custom_et_strings["GREEK","text_19"]="OK. Το αρχικό ESSID θα χρησιμοποιηθεί:"
    custom_et_strings["GREEK","text_20"]="Παρακαλώ εισαγάγετε το επιθυμητό ESSID:"
    custom_et_strings["GREEK","text_21"]="Το ESSID έχει οριστεί σε:"
    custom_et_strings["GREEK","text_22"]="Καμία εισαγωγή. Δημιουργία τυπικού ESSID..."
    custom_et_strings["GREEK","text_23"]="OK. Θα χρησιμοποιηθεί το τυπικό ESSID του Airgeddon."

    # === ITALIAN ===
    custom_et_strings["ITALIAN","text_1"]="Controllo manuale di Evil Twin:"
    custom_et_strings["ITALIAN","text_2"]="Come dovrebbe essere impostato il BSSID per l'Evil Twin?"
    custom_et_strings["ITALIAN","text_3"]="Usa l'esatto BSSID originale"
    custom_et_strings["ITALIAN","text_4"]="Inserisci manualmente un BSSID completamente nuovo"
    custom_et_strings["ITALIAN","text_5"]="Usa il BSSID standard (leggermente modificato) di Airgeddon (predefinito)"
    custom_et_strings["ITALIAN","text_6"]="OK. Verrà utilizzato il BSSID originale:"
    custom_et_strings["ITALIAN","text_7"]="Avviso: Questo potrebbe causare instabilità nella rete!"
    custom_et_strings["ITALIAN","text_8"]="Inserisci il BSSID desiderato (formato XX:XX:XX:XX:XX:XX):"
    custom_et_strings["ITALIAN","text_9"]="Il BSSID è stato impostato su:"
    custom_et_strings["ITALIAN","text_10"]="Formato non valido. Generazione del BSSID standard..."
    custom_et_strings["ITALIAN","text_11"]="OK. Verrà utilizzato il BSSID standard di Airgeddon."
    custom_et_strings["ITALIAN","text_12"]="Canale attuale:"
    custom_et_strings["ITALIAN","text_12b"]="Inserisci un nuovo canale (es. 1-165) o premi Invio per mantenerlo:"
    custom_et_strings["ITALIAN","text_13"]="Il canale è stato impostato su:"
    custom_et_strings["ITALIAN","text_14"]="Mantenimento del canale standard:"
    custom_et_strings["ITALIAN","text_15"]="Come dovrebbe essere impostato l'ESSID (nome AP) per l'Evil Twin?"
    custom_et_strings["ITALIAN","text_16"]="Usa l'esatto ESSID originale"
    custom_et_strings["ITALIAN","text_17"]="Inserisci manualmente un nuovo ESSID"
    custom_et_strings["ITALIAN","text_18"]="Usa l'ESSID standard (falso) di Airgeddon (predefinito)"
    custom_et_strings["ITALIAN","text_19"]="OK. Verrà utilizzato l'ESSID originale:"
    custom_et_strings["ITALIAN","text_20"]="Inserisci l'ESSID desiderato:"
    custom_et_strings["ITALIAN","text_21"]="L'ESSID è stato impostato su:"
    custom_et_strings["ITALIAN","text_22"]="Nessun input. Generazione dell'ESSID standard..."
    custom_et_strings["ITALIAN","text_23"]="OK. Verrà utilizzato l'ESSID standard di Airgeddon."

    # === POLISH ===
    custom_et_strings["POLISH","text_1"]="Ręczna kontrola Evil Twin:"
    custom_et_strings["POLISH","text_2"]="Jak ustawić BSSID dla Evil Twin?"
    custom_et_strings["POLISH","text_3"]="Użyj dokładnego oryginalnego BSSID"
    custom_et_strings["POLISH","text_4"]="Wprowadź całkowicie nowy BSSID ręcznie"
    custom_et_strings["POLISH","text_5"]="Użyj standardowego (lekko zmodyfikowanego) BSSID Airgeddon (domyślnie)"
    custom_et_strings["POLISH","text_6"]="OK. Zostanie użyty oryginalny BSSID:"
    custom_et_strings["POLISH","text_7"]="Ostrzeżenie: Może to spowodować niestabilność w sieci!"
    custom_et_strings["POLISH","text_8"]="Wprowadź żądany BSSID (format XX:XX:XX:XX:XX:XX):"
    custom_et_strings["POLISH","text_9"]="BSSID został ustawiony na:"
    custom_et_strings["POLISH","text_10"]="Nieprawidłowy format. Generowanie standardowego BSSID..."
    custom_et_strings["POLISH","text_11"]="OK. Zostanie użyty standardowy BSSID Airgeddon."
    custom_et_strings["POLISH","text_12"]="Aktualny kanał:"
    custom_et_strings["POLISH","text_12b"]="Wprowadź nowy kanał (np. 1-165) lub naciśnij Enter, aby go zachować:"
    custom_et_strings["POLISH","text_13"]="Kanał został ustawiony na:"
    custom_et_strings["POLISH","text_14"]="Zachowanie standardowego kanału:"
    custom_et_strings["POLISH","text_15"]="Jak ustawić ESSID (nazwę AP) dla Evil Twin?"
    custom_et_strings["POLISH","text_16"]="Użyj dokładnego oryginalnego ESSID"
    custom_et_strings["POLISH","text_17"]="Wprowadź nowy ESSID ręcznie"
    custom_et_strings["POLISH","text_18"]="Użyj standardowego (fałszywego) ESSID Airgeddon (domyślnie)"
    custom_et_strings["POLISH","text_19"]="OK. Zostanie użyty oryginalny ESSID:"
    custom_et_strings["POLISH","text_20"]="Wprowadź żądany ESSID:"
    custom_et_strings["POLISH","text_21"]="ESSID został ustawiony na:"
    custom_et_strings["POLISH","text_22"]="Brak danych. Generowanie standardowego ESSID..."
    custom_et_strings["POLISH","text_23"]="OK. Zostanie użyty standardowy ESSID Airgeddon."

    # === GERMAN ===
    custom_et_strings["GERMAN","text_1"]="Manuelle Evil Twin Kontrolle:"
    custom_et_strings["GERMAN","text_2"]="Wie soll die BSSID für den Evil Twin festgelegt werden?"
    custom_et_strings["GERMAN","text_3"]="Exakte originale BSSID verwenden"
    custom_et_strings["GERMAN","text_4"]="Eine komplett neue BSSID manuell eingeben"
    custom_et_strings["GERMAN","text_5"]="Standard (leicht veränderte) Airgeddon BSSID verwenden (Standard)"
    custom_et_strings["GERMAN","text_6"]="OK. Die originale BSSID wird verwendet:"
    custom_et_strings["GERMAN","text_7"]="Achtung: Dies kann zu Instabilität im Netzwerk führen!"
    custom_et_strings["GERMAN","text_8"]="Geben Sie die gewünschte BSSID ein (Format XX:XX:XX:XX:XX:XX):"
    custom_et_strings["GERMAN","text_9"]="BSSID wurde gesetzt auf:"
    custom_et_strings["GERMAN","text_10"]="Ungültiges Format. Standard-BSSID wird generiert..."
    custom_et_strings["GERMAN","text_11"]="OK. Die Standard Airgeddon BSSID wird verwendet."
    custom_et_strings["GERMAN","text_12"]="Aktueller Kanal:"
    custom_et_strings["GERMAN","text_12b"]="Geben Sie einen neuen Kanal (z.B. 1-165) ein oder drücken Sie Enter, um ihn beizubehalten:"
    custom_et_strings["GERMAN","text_13"]="Kanal wurde gesetzt auf:"
    custom_et_strings["GERMAN","text_14"]="Standard-Kanal wird verwendet:"
    custom_et_strings["GERMAN","text_15"]="Wie soll die ESSID (AP-Name) für den Evil Twin festgelegt werden?"
    custom_et_strings["GERMAN","text_16"]="Exakte originale ESSID verwenden"
    custom_et_strings["GERMAN","text_17"]="Eine neue ESSID manuell eingeben"
    custom_et_strings["GERMAN","text_18"]="Standard (gefälschte) Airgeddon ESSID verwenden (Standard)"
    custom_et_strings["GERMAN","text_19"]="OK. Die originale ESSID wird verwendet:"
    custom_et_strings["GERMAN","text_20"]="Geben Sie die gewünschte ESSID ein:"
    custom_et_strings["GERMAN","text_21"]="ESSID wurde gesetzt auf:"
    custom_et_strings["GERMAN","text_22"]="Keine Eingabe. Standard-ESSID wird generiert..."
    custom_et_strings["GERMAN","text_23"]="OK. Die Standard Airgeddon ESSID wird verwendet."

    # === TURKISH ===
    custom_et_strings["TURKISH","text_1"]="Manuel Evil Twin kontrolü:"
    custom_et_strings["TURKISH","text_2"]="Evil Twin için BSSID nasıl ayarlanmalı?"
    custom_et_strings["TURKISH","text_3"]="Tam orijinal BSSID'yi kullan"
    custom_et_strings["TURKISH","text_4"]="Tamamen yeni bir BSSID'yi manuel olarak girin"
    custom_et_strings["TURKISH","text_5"]="Standart (hafif değiştirilmiş) Airgeddon BSSID'sini kullan (varsayılan)"
    custom_et_strings["TURKISH","text_6"]="TAMAM. Orijinal BSSID kullanılacak:"
    custom_et_strings["TURKISH","text_7"]="Uyarı: Bu ağda kararsızlığa neden olabilir!"
    custom_et_strings["TURKISH","text_8"]="Lütfen istenen BSSID'yi girin (format XX:XX:XX:XX:XX:XX):"
    custom_et_strings["TURKISH","text_9"]="BSSID şuna ayarlandı:"
    custom_et_strings["TURKISH","text_10"]="Geçersiz format. Standart BSSID oluşturuluyor..."
    custom_et_strings["TURKISH","text_11"]="TAMAM. Standart Airgeddon BSSID kullanılacak."
    custom_et_strings["TURKISH","text_12"]="Mevcut kanal:"
    custom_et_strings["TURKISH","text_12b"]="Yeni bir kanal girin (ör. 1-165) veya mevcut olanı korumak için Enter'a basın:"
    custom_et_strings["TURKISH","text_13"]="Kanal şuna ayarlandı:"
    custom_et_strings["TURKISH","text_14"]="Standart kanal korunuyor:"
    custom_et_strings["TURKISH","text_15"]="Evil Twin için ESSID (AP adı) nasıl ayarlanmalı?"
    custom_et_strings["TURKISH","text_16"]="Tam orijinal ESSID'yi kullan"
    custom_et_strings["TURKISH","text_17"]="Yeni bir ESSID'yi manuel olarak girin"
    custom_et_strings["TURKISH","text_18"]="Standart (sahte) Airgeddon ESSID'sini kullan (varsayılan)"
    custom_et_strings["TURKISH","text_19"]="TAMAM. Orijinal ESSID kullanılacak:"
    custom_et_strings["TURKISH","text_20"]="Lütfen istenen ESSID'yi girin:"
    custom_et_strings["TURKISH","text_21"]="ESSID şuna ayarlandı:"
    custom_et_strings["TURKISH","text_22"]="Giriş yok. Standart ESSID oluşturuluyor..."
    custom_et_strings["TURKISH","text_23"]="TAMAM. Standart Airgeddon ESSID kullanılacak."

    # === ARABIC ===
    custom_et_strings["ARABIC","text_1"]="التحكم اليدوي في Evil Twin:"
    custom_et_strings["ARABIC","text_2"]="كيف يجب تعيين BSSID لـ Evil Twin؟"
    custom_et_strings["ARABIC","text_3"]="استخدام BSSID الأصلي بالضبط"
    custom_et_strings["ARABIC","text_4"]="إدخال BSSID جديد تمامًا يدويًا"
    custom_et_strings["ARABIC","text_5"]="استخدام BSSID الافتراضي (المعدل قليلاً) لـ Airgeddon (الافتراضي)"
    custom_et_strings["ARABIC","text_6"]="حسنا. سيتم استخدام BSSID الأصلي:"
    custom_et_strings["ARABIC","text_7"]="تحذير: قد يسبب هذا عدم استقرار في الشبكة!"
    custom_et_strings["ARABIC","text_8"]="الرجاء إدخال BSSID المطلوب (بالتنسيق XX:XX:XX:XX:XX:XX):"
    custom_et_strings["ARABIC","text_9"]="تم تعيين BSSID إلى:"
    custom_et_strings["ARABIC","text_10"]="تنسيق غير صالح. جارٍ إنشاء BSSID الافتراضي..."
    custom_et_strings["ARABIC","text_11"]="حسنا. سيتم استخدام BSSID الافتراضي لـ Airgeddon."
    custom_et_strings["ARABIC","text_12"]="القناة الحالية:"
    custom_et_strings["ARABIC","text_12b"]="أدخل قناة جديدة (مثلاً 1-165) أو اضغط Enter للاحتفاظ بها:"
    custom_et_strings["ARABIC","text_13"]="تم تعيين القناة إلى:"
    custom_et_strings["ARABIC","text_14"]="الاحتفاظ بالقناة القياسية:"
    custom_et_strings["ARABIC","text_15"]="كيف يجب تعيين ESSID (اسم نقطة الوصول) لـ Evil Twin؟"
    custom_et_strings["ARABIC","text_16"]="استخدام ESSID الأصلي بالضبط"
    custom_et_strings["ARABIC","text_17"]="إدخال ESSID جديد يدويًا"
    custom_et_strings["ARABIC","text_18"]="استخدام ESSID الافتراضي (المزيف) لـ Airgeddon (الافتراضي)"
    custom_et_strings["ARABIC","text_19"]="حسنا. سيتم استخدام ESSID الأصلي:"
    custom_et_strings["ARABIC","text_20"]="الرجاء إدخال ESSID المطلوب:"
    custom_et_strings["ARABIC","text_21"]="تم تعيين ESSID إلى:"
    custom_et_strings["ARABIC","text_22"]="لا يوجد إدخال. جارٍ إنشاء ESSID الافتراضي..."
    custom_et_strings["ARABIC","text_23"]="حسنا. سيتم استخدام ESSID الافتراضي لـ Airgeddon."

    # === CHINESE ===
    custom_et_strings["CHINESE","text_1"]="Evil Twin 手动控制："
    custom_et_strings["CHINESE","text_2"]="应该如何设置 Evil Twin 的 BSSID？"
    custom_et_strings["CHINESE","text_3"]="使用确切的原始 BSSID"
    custom_et_strings["CHINESE","text_4"]="手动输入一个全新的 BSSID"
    custom_et_strings["CHINESE","text_5"]="使用标准（稍作修改的）Airgeddon BSSID（默认）"
    custom_et_strings["CHINESE","text_6"]="好的。将使用原始 BSSID："
    custom_et_strings["CHINESE","text_7"]="警告：这可能会导致网络不稳定！"
    custom_et_strings["CHINESE","text_8"]="请输入所需的 BSSID（格式 XX:XX:XX:XX:XX:XX）："
    custom_et_strings["CHINESE","text_9"]="BSSID 已设置为："
    custom_et_strings["CHINESE","text_10"]="格式无效。正在生成标准 BSSID..."
    custom_et_strings["CHINESE","text_11"]="好的。将使用标准 Airgeddon BSSID。"
    custom_et_strings["CHINESE","text_12"]="当前信道："
    custom_et_strings["CHINESE","text_12b"]="输入新信道（例如 1-165）或按回车键保持不变："
    custom_et_strings["CHINESE","text_13"]="信道已设置为："
    custom_et_strings["CHINESE","text_14"]="保持标准信道："
    custom_et_strings["CHINESE","text_15"]="应该如何设置 Evil Twin 的 ESSID（AP名称）？"
    custom_et_strings["CHINESE","text_16"]="使用确切的原始 ESSID"
    custom_et_strings["CHINESE","text_17"]="手动输入新的 ESSID"
    custom_et_strings["CHINESE","text_18"]="使用标准（伪造的）Airgeddon ESSID（默认）"
    custom_et_strings["CHINESE","text_19"]="好的。将使用原始 ESSID："
    custom_et_strings["CHINESE","text_20"]="请输入所需的 ESSID："
    custom_et_strings["CHINESE","text_21"]="ESSID 已设置为："
    custom_et_strings["CHINESE","text_22"]="无输入。正在生成标准 ESSID..."
    custom_et_strings["CHINESE","text_23"]="好的。将使用标准 Airgeddon ESSID。"
}
