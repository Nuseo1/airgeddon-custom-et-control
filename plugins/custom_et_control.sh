#!/usr/bin/env bash

#Global shellcheck disabled warnings
#shellcheck disable=SC2034,SC2154

plugin_name="Manual Evil Twin Control"
plugin_description="Plugin for manually selecting the BSSID, channel, and ESSID for Evil Twin attacks."
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
# Sprach-Strings Initialisierung (Globaler Scope)
# -------------------------------------------------------------
custom_et_strings[GERMAN_text_1]="Manuelle Evil Twin Kontrolle:"
custom_et_strings[GERMAN_text_2]="Wie soll die BSSID für den Evil Twin festgelegt werden?"
custom_et_strings[GERMAN_text_3]="Exakte originale BSSID verwenden"
custom_et_strings[GERMAN_text_4]="Eine komplett neue BSSID manuell eingeben"
custom_et_strings[GERMAN_text_5]="Standard (leicht veränderte) Airgeddon BSSID verwenden (Standard)"
custom_et_strings[GERMAN_text_6]="OK. Die originale BSSID wird verwendet:"
custom_et_strings[GERMAN_text_7]="Achtung: Dies kann zu Instabilität im Netzwerk führen!"
custom_et_strings[GERMAN_text_8]="Geben Sie die gewünschte BSSID ein (Format XX:XX:XX:XX:XX:XX):"
custom_et_strings[GERMAN_text_9]="BSSID wurde gesetzt auf:"
custom_et_strings[GERMAN_text_10]="Ungültiges Format. Standard-BSSID wird generiert..."
custom_et_strings[GERMAN_text_11]="OK. Die Standard Airgeddon BSSID wird verwendet."
custom_et_strings[GERMAN_text_12]="Aktueller Kanal:"
custom_et_strings[GERMAN_text_12b]="Geben Sie einen neuen Kanal (z.B. 1-165) ein oder drücken Sie Enter, um ihn beizubehalten:"
custom_et_strings[GERMAN_text_13]="Kanal wurde gesetzt auf:"
custom_et_strings[GERMAN_text_14]="Standard-Kanal wird verwendet:"
custom_et_strings[GERMAN_text_15]="Wie soll die ESSID (AP-Name) für den Evil Twin festgelegt werden?"
custom_et_strings[GERMAN_text_16]="Exakte originale ESSID verwenden"
custom_et_strings[GERMAN_text_17]="Eine neue ESSID manuell eingeben"
custom_et_strings[GERMAN_text_18]="Standard (gefälschte) Airgeddon ESSID verwenden (Standard)"
custom_et_strings[GERMAN_text_19]="OK. Die exakte originale ESSID wird verwendet:"
custom_et_strings[GERMAN_text_20]="Geben Sie die gewünschte ESSID ein:"
custom_et_strings[GERMAN_text_21]="ESSID wurde gesetzt auf:"
custom_et_strings[GERMAN_text_22]="Keine Eingabe. Standard-ESSID wird generiert..."
custom_et_strings[GERMAN_text_23]="OK. Die Standard Airgeddon ESSID wird verwendet."

# Fallback auf Englisch
custom_et_strings[ENGLISH_text_1]="Manual Evil Twin control:"
custom_et_strings[ENGLISH_text_2]="How should the BSSID for the Evil Twin be set?"
custom_et_strings[ENGLISH_text_3]="Use exact original BSSID"
custom_et_strings[ENGLISH_text_4]="Enter a completely new BSSID manually"
custom_et_strings[ENGLISH_text_5]="Use standard (slightly modified) Airgeddon BSSID (default)"
custom_et_strings[ENGLISH_text_6]="OK. Original BSSID will be used:"
custom_et_strings[ENGLISH_text_7]="Warning: This may cause instability in the network!"
custom_et_strings[ENGLISH_text_8]="Please enter the desired BSSID (format XX:XX:XX:XX:XX:XX):"
custom_et_strings[ENGLISH_text_9]="BSSID has been set to:"
custom_et_strings[ENGLISH_text_10]="Invalid format. Generating standard BSSID..."
custom_et_strings[ENGLISH_text_11]="OK. Standard Airgeddon BSSID will be used."
custom_et_strings[ENGLISH_text_12]="Current channel:"
custom_et_strings[ENGLISH_text_12b]="Enter a new channel (e.g. 1-165) or press Enter to keep it:"
custom_et_strings[ENGLISH_text_13]="Channel has been set to:"
custom_et_strings[ENGLISH_text_14]="Keeping standard channel:"
custom_et_strings[ENGLISH_text_15]="How should the ESSID (AP name) for the Evil Twin be set?"
custom_et_strings[ENGLISH_text_16]="Use exact original ESSID"
custom_et_strings[ENGLISH_text_17]="Enter a new ESSID manually"
custom_et_strings[ENGLISH_text_18]="Use standard (fake) Airgeddon ESSID (default)"
custom_et_strings[ENGLISH_text_19]="OK. Exact original ESSID will be used:"
custom_et_strings[ENGLISH_text_20]="Please enter the desired ESSID:"
custom_et_strings[ENGLISH_text_21]="ESSID has been set to:"
custom_et_strings[ENGLISH_text_22]="No input. Generating standard ESSID..."
custom_et_strings[ENGLISH_text_23]="OK. Standard Airgeddon ESSID will be used."


# -------------------------------------------------------------
# Zentrale Funktion: Abfrage-Menü (Läuft im Prehook)
# -------------------------------------------------------------
function _custom_et_interactive_prompt() {
	debug_print

	local lang_key="${language}"
	if [[ -z "${custom_et_strings[${lang_key}_text_1]}" ]]; then
		lang_key="ENGLISH"
	fi

	# Variablen zurücksetzen
	custom_et_chosen_bssid=""
	custom_et_chosen_essid=""

	echo
	echo -e "${yellow_color}${custom_et_strings[${lang_key}_text_1]}${normal_color}"
	echo

	# --- 1. BSSID AUSWAHL ---
	echo -e "${cyan_color}${custom_et_strings[${lang_key}_text_2]}${normal_color}"
	echo -e "1. ${custom_et_strings[${lang_key}_text_3]} (${bssid})"
	echo -e "2. ${custom_et_strings[${lang_key}_text_4]}"
	echo -e "3. ${custom_et_strings[${lang_key}_text_5]}"
	read -rp "> " bssid_choice

	case "${bssid_choice}" in
		1)
			custom_et_chosen_bssid="${bssid}"
			echo -e "${green_color}${custom_et_strings[${lang_key}_text_6]} ${custom_et_chosen_bssid}${normal_color}"
			echo -e "${red_color}${custom_et_strings[${lang_key}_text_7]}${normal_color}"
			;;
		2)
			echo -e "${green_color}${custom_et_strings[${lang_key}_text_8]}${normal_color}"
			read -rp "> " custom_bssid
			if [[ -n "${custom_bssid}" && "${custom_bssid}" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
				custom_et_chosen_bssid="${custom_bssid}"
				echo -e "${green_color}${custom_et_strings[${lang_key}_text_9]} ${custom_et_chosen_bssid}${normal_color}"
			else
				echo -e "${red_color}${custom_et_strings[${lang_key}_text_10]}${normal_color}"
			fi
			;;
		*)
			echo -e "${green_color}${custom_et_strings[${lang_key}_text_11]}${normal_color}"
			;;
	esac

	# --- 2. KANAL AUSWAHL ---
	echo
	echo -e "${cyan_color}${custom_et_strings[${lang_key}_text_12]} ${channel}${normal_color}"
	echo -e "${cyan_color}${custom_et_strings[${lang_key}_text_12b]}${normal_color}"
	read -rp "> " custom_channel
	
	if [[ -n "${custom_channel}" && "${custom_channel}" =~ ^[0-9]+$ && "${custom_channel}" -gt 0 && "${custom_channel}" -le 196 ]]; then
		channel="${custom_channel}" # Die Kanal-Variable überschreiben
		echo "${channel}" > "${tmpdir}${channelfile}"
		echo -e "${green_color}${custom_et_strings[${lang_key}_text_13]} ${channel}${normal_color}"
	else
		echo -e "${green_color}${custom_et_strings[${lang_key}_text_14]} ${channel}${normal_color}"
	fi

	# --- 3. ESSID AUSWAHL ---
	echo
	echo -e "${cyan_color}${custom_et_strings[${lang_key}_text_15]}${normal_color}"
	echo -e "1. ${custom_et_strings[${lang_key}_text_16]} (${essid})"
	echo -e "2. ${custom_et_strings[${lang_key}_text_17]}"
	echo -e "3. ${custom_et_strings[${lang_key}_text_18]}"
	read -rp "> " essid_choice

	case "${essid_choice}" in
		1)
			# Original ESSID MIT Zero-Width Space
			custom_et_chosen_essid=$(echo -e "${essid}\xE2\x80\x8B")
			echo -e "${green_color}${custom_et_strings[${lang_key}_text_19]} \"${essid}\" (mit Zero-Width Space)${normal_color}"
			;;
		2)
			echo -e "${green_color}${custom_et_strings[${lang_key}_text_20]}${normal_color}"
			read -rp "> " custom_essid
			if [[ -n "${custom_essid}" ]]; then
				# Manuelle ESSID MIT Zero-Width Space (damit das Captive Portal perfekt greift)
				custom_et_chosen_essid=$(echo -e "${custom_essid}\xE2\x80\x8B")
				echo -e "${green_color}${custom_et_strings[${lang_key}_text_21]} \"${custom_essid}\" (mit Zero-Width Space)${normal_color}"
			else
				echo -e "${yellow_color}${custom_et_strings[${lang_key}_text_22]}${normal_color}"
			fi
			;;
		*)
			# Standard Airgeddon ESSID MIT Zero-Width Space
			custom_et_chosen_essid=$(echo -e "${essid}\xE2\x80\x8B")
			echo -e "${green_color}${custom_et_strings[${lang_key}_text_23]} \"${essid}\" (mit Zero-Width Space)${normal_color}"
			;;
	esac

	echo
	sleep 2

	# NUR et_essid und et_bssid übergeben, bssid und essid bleiben für den Deauth unberührt!
	if [[ -n "${custom_et_chosen_essid}" ]]; then
		et_essid="${custom_et_chosen_essid}"
	fi
	if [[ -n "${custom_et_chosen_bssid}" ]]; then
		et_bssid="${custom_et_chosen_bssid}"
	fi
}

# -------------------------------------------------------------
# PREHOOKS (Vor der Konfigurationserstellung)
# -------------------------------------------------------------
function custom_et_control_prehook_set_hostapd_config() { _custom_et_interactive_prompt; }
function custom_et_control_prehook_set_hostapd_wpe_config() { _custom_et_interactive_prompt; }
function custom_et_control_prehook_set_hostapd_mana_config() { _custom_et_interactive_prompt; }

# Prehook für das Captive Portal (Sicherstellen, dass die Werte im HTML-Code ankommen)
function custom_et_control_prehook_set_captive_portal_page() {
    if [[ -n "${custom_et_chosen_essid}" ]]; then
        et_essid="${custom_et_chosen_essid}"
    fi
    if [[ -n "${custom_et_chosen_bssid}" ]]; then
        et_bssid="${custom_et_chosen_bssid}"
    fi
}

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
		local safe_essid
		safe_essid=$(printf '%s' "${et_essid}" | sed 's/[&/|]/\\&/g')
		sed -ri "s|^ssid=.*|ssid=${safe_essid}|" "${target_config_file}" 2> /dev/null
	fi
}

function custom_et_control_posthook_set_hostapd_config() { _apply_custom_et_config "${tmpdir}${hostapd_file}"; }
function custom_et_control_posthook_set_hostapd_wpe_config() { _apply_custom_et_config "${tmpdir}${hostapd_wpe_file}"; }
function custom_et_control_posthook_set_hostapd_mana_config() { _apply_custom_et_config "${tmpdir}${hostapd_mana_file}"; }
