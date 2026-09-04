#!/bin/sh

set -eu

# Keep these sentinels split so release publishing only rewrites the configured
# values below; local or unpublished copies still need unreplaced values to compare.
amide_unconfigured_base_url="__AMIDE_DOWNLOAD_BASE""_URL__"
amide_unconfigured_default_release_channel="__AMIDE_DEFAULT_RELEASE_""CHANNEL__"
amide_base_url="${AMIDE_DOWNLOAD_BASE_URL:-__AMIDE_DOWNLOAD_BASE_URL__}"
amide_base_url="${amide_base_url%/}"
amide_default_release_channel="__AMIDE_DEFAULT_RELEASE_CHANNEL__"
if [ "$amide_default_release_channel" = "$amide_unconfigured_default_release_channel" ]; then
	amide_default_release_channel=stable
fi
amide_release_channel="${AMIDE_RELEASE_CHANNEL:-$amide_default_release_channel}"
amide_package="${AMIDE_PACKAGE:-amide}"
amide_cmd="${AMIDE_CMD:-amide}"
amide_esc=$(printf '\033')
amide_original_path="${PATH:-}"
amide_reset="${amide_esc}[0m"
amide_bold="${amide_esc}[1m"
amide_italic="${amide_esc}[3m"
amide_hide_cursor="${amide_esc}[?25l"
amide_show_cursor="${amide_esc}[?25h"
amide_home_cursor="${amide_esc}[H"
amide_clear_screen="${amide_esc}[2J${amide_esc}[H"
amide_clear_line="${amide_esc}[K"
amide_sync_start="${amide_esc}[?2026h"
amide_sync_end="${amide_esc}[?2026l"
amide_color_text="${amide_esc}[38;2;244;244;245m"
amide_color_muted="${amide_esc}[38;2;161;161;170m"
amide_color_dim="${amide_esc}[38;2;113;113;122m"
amide_color_primary="${amide_esc}[38;2;127;91;213m"
amide_color_scan="${amide_esc}[38;2;14;165;233m"
amide_color_warning="${amide_esc}[38;2;245;158;11m"
readonly amide_unconfigured_base_url amide_unconfigured_default_release_channel amide_base_url amide_default_release_channel amide_release_channel amide_package amide_cmd amide_esc amide_original_path
readonly amide_reset amide_bold amide_italic amide_hide_cursor amide_show_cursor amide_home_cursor amide_clear_screen amide_clear_line
readonly amide_sync_start amide_sync_end
readonly amide_color_text amide_color_muted amide_color_dim amide_color_primary amide_color_scan amide_color_warning

amide_screen_enabled=0
amide_screen_frame=0
amide_screen_cols=80
amide_screen_rows=24
amide_screen_drawn=0
amide_screen_last_cols=0
amide_screen_last_rows=0
amide_screen_layout_ready=0
amide_screen_layout_show_logo=0
amide_screen_layout_lab_width=0
amide_screen_render_lab_width=0
amide_screen_compact=0
amide_download_dir=
amide_bootstrap_kernel_on_install=0
amide_screen_title=
amide_screen_status=
amide_screen_detail=
amide_screen_question=
amide_animation_frame=0

main() {
	if [ "$amide_base_url" = "$amide_unconfigured_base_url" ]; then
		printf 'error: installer download URL is not configured.\n' >&2
		printf 'Set AMIDE_DOWNLOAD_BASE_URL or use the installer published by the release workflow.\n' >&2
		exit 1
	fi

	amide_install_traps
	amide_init_screen
	if [ "$amide_screen_enabled" = 1 ]; then
		amide_screen "Installing AMIDE" "" "" ""
	else
		printf '\n\033[1m  Installing AMIDE\033[0m\n\033[2m  npm global install\033[0m\n\n'
	fi

	start_preflight_checks

	if finish_preflight_checks; then
		check_status=0
	else
		check_status=$?
	fi

	if [ "$check_status" -ne 0 ]; then
		if ! install_node_npm_interactive; then
			exit "$check_status"
		fi

		start_preflight_checks
		if finish_preflight_checks; then
			check_status=0
		else
			check_status=$?
		fi

		if [ "$check_status" -ne 0 ]; then
			exit "$check_status"
		fi
	fi

	version="$(resolve_amide_version "$@")"
	tarball_name="$amide_package-$version.tgz"
	tarball_url="$amide_base_url/releases/v$version/$tarball_name"

	confirm_install "$version" "$tarball_url"
	confirm_kernel_runtime_setup

	download_dir=$(create_temp_dir)
	amide_download_dir="$download_dir"
	tarball_path="$download_dir/$tarball_name"

	download_amide_package "$version" "$tarball_url" "$tarball_path"
	install_amide_package "$tarball_path"
	rm -rf "$download_dir"
	amide_download_dir=

	if [ "${AMIDE_NODE_INSTALLED_STANDALONE:-0}" = 1 ]; then
		amide_screen "AMIDE installed" "" "Checking your shell PATH." ""
		configure_standalone_node_path
	elif command -v "$amide_cmd" >/dev/null 2>&1; then
		if [ "$amide_screen_enabled" = 1 ]; then
			amide_screen "AMIDE installed" "" "Run it with: $amide_cmd" ""
		else
			printf '\nAMIDE was installed successfully.\n'
			printf '\nRun it with: %s\n' "$amide_cmd"
		fi
	else
		if [ "$amide_screen_enabled" = 1 ]; then
			amide_screen "AMIDE installed" "" "PATH update needed for $amide_cmd." ""
			amide_restore_terminal
		else
			printf '\nAMIDE was installed successfully.\n'
		fi
		cat <<EOF
The $amide_cmd command was installed, but it is not on your PATH yet.
Check npm's global bin directory with:

  npm bin -g

Then add that directory to your shell PATH.
EOF
	fi
}

create_temp_dir() {
	if command -v mktemp >/dev/null 2>&1; then
		if tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/amide-install.XXXXXX" 2>/dev/null); then
			printf '%s' "$tmp_dir"
			return
		fi
	fi

	printf 'error: mktemp is required to create a secure temporary directory.\n' >&2
	exit 1
}

amide_install_traps() {
	trap 'amide_cleanup' EXIT
	trap 'amide_signal_cleanup 130' INT
	trap 'amide_signal_cleanup 143' TERM
}

amide_cleanup() {
	status=$?
	if [ -n "${amide_download_dir:-}" ] && [ -d "$amide_download_dir" ]; then
		rm -rf "$amide_download_dir"
	fi
	amide_restore_terminal
	return "$status"
}

amide_signal_cleanup() {
	amide_restore_terminal
	exit "$1"
}

amide_restore_terminal() {
	if [ "${amide_screen_enabled:-0}" = 1 ]; then
		if ( : <>/dev/tty ) 2>/dev/null; then
			printf '%s%s' "$amide_reset" "$amide_show_cursor" >/dev/tty
		else
			printf '%s%s' "$amide_reset" "$amide_show_cursor" >&2
		fi
	fi
}

amide_init_screen() {
	if [ "${AMIDE_INSTALLER_PLAIN:-0}" = 1 ]; then
		return
	fi
	if [ ! -t 1 ]; then
		return
	fi
	if [ "${TERM:-}" = dumb ]; then
		return
	fi
	amide_screen_enabled=1
}

amide_read_terminal_size() {
	amide_screen_cols=80
	amide_screen_rows=24

	if size=$(stty size 2>/dev/null </dev/tty); then
		set -- $size
		if [ "${1:-}" ] && [ "${2:-}" ]; then
			case "$1" in *[!0-9]*|"") ;; *) amide_screen_rows="$1" ;; esac
			case "$2" in *[!0-9]*|"") ;; *) amide_screen_cols="$2" ;; esac
		fi
	fi

	if [ "$amide_screen_cols" -lt 1 ]; then
		amide_screen_cols=80
	fi
	if [ "$amide_screen_rows" -lt 1 ]; then
		amide_screen_rows=24
	fi
}

amide_screen() {
	if [ "$amide_screen_enabled" != 1 ]; then
		return
	fi

	amide_screen_title="${2:-$1}"
	if [ -z "$amide_screen_title" ]; then
		amide_screen_title="$1"
	fi
	amide_screen_status=
	amide_screen_detail="${3:-}"
	amide_screen_question="${4:-}"
	amide_screen_frame=$((amide_screen_frame + 1))
	amide_read_terminal_size
	amide_init_screen_layout
	amide_refresh_screen_layout_mode

	if [ "$amide_screen_drawn" = 0 ] ||
		[ "$amide_screen_cols" -ne "$amide_screen_last_cols" ] ||
		[ "$amide_screen_rows" -ne "$amide_screen_last_rows" ]; then
		amide_screen_prefix="${amide_reset}${amide_clear_screen}${amide_hide_cursor}"
		amide_screen_drawn=1
		amide_screen_last_cols="$amide_screen_cols"
		amide_screen_last_rows="$amide_screen_rows"
	else
		amide_screen_prefix="${amide_reset}${amide_home_cursor}${amide_hide_cursor}"
	fi
	amide_screen_frame_text=$(amide_render_screen)

	if ( : <>/dev/tty ) 2>/dev/null; then
		printf '%s%s%s%s' "$amide_sync_start" "$amide_screen_prefix" "$amide_screen_frame_text" "$amide_sync_end" >/dev/tty
	else
		printf '%s%s%s%s' "$amide_sync_start" "$amide_screen_prefix" "$amide_screen_frame_text" "$amide_sync_end" >&2
	fi
}

amide_init_screen_layout() {
	if [ "$amide_screen_layout_ready" = 1 ]; then
		return
	fi

	amide_screen_layout_ready=1
	amide_screen_layout_show_logo=0
	amide_screen_layout_lab_width=0
	amide_screen_render_lab_width=0
	if amide_terminal_size_supports_logo; then
		amide_screen_layout_show_logo=1
		amide_screen_layout_lab_width=$(amide_lab_width_for_cols "$amide_screen_cols")
	fi
}

amide_refresh_screen_layout_mode() {
	amide_screen_compact=0
	amide_screen_render_lab_width=0
	if [ "$amide_screen_layout_show_logo" != 1 ]; then
		return
	fi
	if [ "$amide_screen_rows" -lt 17 ]; then
		amide_screen_compact=1
		return
	fi

	max_safe_width=$((amide_screen_cols - 1))
	if [ "$max_safe_width" -lt 32 ]; then
		amide_screen_compact=1
		return
	fi

	amide_screen_render_lab_width="$amide_screen_layout_lab_width"
	if [ "$amide_screen_render_lab_width" -gt "$max_safe_width" ]; then
		amide_screen_render_lab_width="$max_safe_width"
	fi
}

amide_terminal_size_supports_logo() {
	[ "$amide_screen_rows" -ge 22 ] && [ "$amide_screen_cols" -ge 42 ]
}

amide_lab_width_for_cols() {
	cols="$1"
	width=$((cols - 6))
	if [ "$width" -gt 78 ]; then
		width=78
	fi
	if [ "$width" -lt 42 ]; then
		width=42
	fi
	max_safe_width=$((cols - 1))
	if [ "$max_safe_width" -lt 1 ]; then
		max_safe_width=1
	fi
	if [ "$width" -gt "$max_safe_width" ]; then
		width="$max_safe_width"
	fi
	if [ "$width" -lt 32 ]; then
		width=32
	fi
	printf '%s' "$width"
}

amide_render_screen() {
	content_height=$(amide_content_height)
	top=$(((amide_screen_rows - content_height) / 2))
	if [ "$top" -lt 0 ]; then
		top=0
	fi

	y=0
	while [ "$y" -lt "$amide_screen_rows" ]; do
		content_index=$((y - top))
		amide_content_line "$content_index"
		if [ "${amide_content_is_set:-0}" = 1 ]; then
			amide_print_centered_line "$amide_content_text" "$amide_content_width" "$amide_content_style"
		else
			amide_print_centered_line "" 0 ""
		fi
		y=$((y + 1))
	done
}

amide_content_height() {
	height=2
	if amide_show_logo; then
		height=$((height + 15))
	fi
	printf '%s' "$height"
}

amide_show_logo() {
	[ "$amide_screen_layout_show_logo" = 1 ] && [ "$amide_screen_compact" != 1 ] && [ "$amide_screen_render_lab_width" -ge 32 ]
}

amide_content_line() {
	index="$1"
	amide_content_is_set=0
	amide_content_text=
	amide_content_width=0
	amide_content_style=

	if amide_show_logo; then
		case "$index" in
			0|1|2|3|4|5|6|7|8|9|10|11|12|13) amide_set_lab_line "$index" ;;
			14) amide_set_blank_line ;;
		esac
		if [ "$amide_content_is_set" = 1 ]; then
			return
		fi
		index=$((index - 15))
	fi

	if [ "$index" -lt 0 ]; then
		return
	fi

	if [ "$index" -eq 0 ]; then
		if [ -n "$amide_screen_question" ]; then
			amide_set_text_line "$(amide_screen_primary_text)" "$amide_bold$amide_color_text"
		else
			amide_set_title_line "$amide_screen_title"
		fi
		return
	fi

	if [ "$index" -eq 1 ]; then
		if [ -n "$amide_screen_question" ]; then
			amide_set_text_line "Press Enter to continue; type n to cancel." "$amide_color_muted"
		elif [ -n "$amide_screen_detail" ]; then
			amide_set_text_line "$amide_screen_detail" "$amide_color_muted"
		else
			amide_set_blank_line
		fi
		return
	fi
}

amide_screen_primary_text() {
	if [ -z "$amide_screen_question" ]; then
		printf '%s' "$amide_screen_title"
		return
	fi

	case "$amide_screen_question" in
		*'[Y/n]'*) printf '%s [Y/n] >' "$amide_screen_title" ;;
		*) printf '%s %s' "$amide_screen_title" "$amide_screen_question" ;;
	esac
}

amide_set_lab_line() {
	lab_row="$1"
	amide_lab_width="$amide_screen_render_lab_width"

	logo_line=$(amide_logo_line "$lab_row")
	if [ -n "$logo_line" ]; then
		logo_start=$(((amide_lab_width - 32) / 2))
		logo_end=$((logo_start + 32))
		left=$(amide_lab_background_range "$lab_row" 0 "$logo_start")
		right=$(amide_lab_background_range "$lab_row" "$logo_end" "$amide_lab_width")
		trace="${left}${amide_color_text}${logo_line}${amide_reset}${right}"
	else
		trace=$(amide_lab_background_range "$lab_row" 0 "$amide_lab_width")
	fi

	amide_content_is_set=1
	amide_content_text="$trace"
	amide_content_width="$amide_lab_width"
	amide_content_style=
}

amide_logo_line() {
	case "$1" in
		2) printf '                          ▄▄███▀' ;;
		3) printf '    ▄▄▄▄▄              ▄█████▀' ;;
		4) printf '    ██████▄         ▄██████▀' ;;
		5) printf '   ▄███▀███▄     ▄███▀▄██▀' ;;
		6) printf '   ███ ▄████▄▄▄████▀▄▄██' ;;
		7) printf '  ▀██  ▀█████████▀▀▀▀▀▀' ;;
		8) printf '  ▄██   ██████▀▀ ▄███' ;;
		9) printf ' █████    ▀█▄▄▄█████▀' ;;
		10) printf '███████▄  ████████▀' ;;
		11) printf '▀███▀▀    █████▀' ;;
	esac
}

amide_lab_background_range() {
	lab_row="$1"
	range_start="$2"
	range_end="$3"
	active_style=
	line=
	x="$range_start"
	while [ "$x" -lt "$range_end" ]; do
		amide_lab_cell "$x" "$lab_row"
		if [ "$amide_lab_cell_style" != "$active_style" ]; then
			if [ -n "$active_style" ]; then
				line="${line}${amide_reset}"
			fi
			if [ -n "$amide_lab_cell_style" ]; then
				line="${line}${amide_lab_cell_style}"
			fi
			active_style="$amide_lab_cell_style"
		fi
		line="${line}${amide_lab_cell_char}"
		x=$((x + 1))
	done
	if [ -n "$active_style" ]; then
		line="${line}${amide_reset}"
	fi
	printf '%s' "$line"
}

amide_lab_cell() {
	x="$1"
	y="$2"
	width="$amide_lab_width"
	height=14
	frame="$amide_screen_frame"
	amide_lab_cell_char=" "
	amide_lab_cell_style=

	hash=$(((x * 37 + y * 53 + frame * 11 + x * y * 3) % 101))
	if [ "$hash" -lt 3 ]; then
		amide_lab_cell_char="·"
		amide_lab_cell_style="$amide_color_dim"
	fi

	center_x=$((width * 36 / 100))
	center_y=$((height * 54 / 100))
	dx=$((x - center_x))
	dy=$((y - center_y))
	if [ "$dx" -lt 0 ]; then
		dx=$((-dx))
	fi
	if [ "$dy" -lt 0 ]; then
		dy=$((-dy))
	fi
	contour=$((dx + dy * 4 + x / 6 - frame))
	if [ "$x" -lt $((width * 82 / 100)) ] && [ $(((contour % 24 + 24) % 24)) -eq 12 ]; then
		if [ $(((x + y) % 5)) -eq 0 ]; then
			amide_lab_cell_char="╌"
		else
			amide_lab_cell_char="·"
		fi
		amide_lab_cell_style="$amide_color_dim"
	fi

	horizon_y=$((height * 58 / 100))
	if [ "$y" -eq "$horizon_y" ] && [ $((x % 2)) -eq 0 ] && [ $(((x + frame) % 13)) -lt 2 ]; then
		amide_lab_cell_char="─"
		if [ "$x" -gt $((width * 60 / 100)) ]; then
			amide_lab_cell_style="$amide_color_primary"
		else
			amide_lab_cell_style="$amide_color_dim"
		fi
	fi

	scan_start=$((width / 2))
	if [ "$x" -ge "$scan_start" ]; then
		scan_offset=$((x - scan_start))
		if [ $((scan_offset % 5)) -eq 0 ]; then
			scan_index=$((scan_offset / 5))
			scan_top=$((1 + (scan_index + frame / 3) % 3))
			scan_bottom=$((height - 2 - (scan_index * 2 + frame / 4) % 3))
			if [ "$y" -ge "$scan_top" ] && [ "$y" -le "$scan_bottom" ] && [ $(((y + scan_index + frame) % 6)) -ne 0 ]; then
				if [ $(((scan_index + y) % 4)) -eq 0 ]; then
					amide_lab_cell_char="┃"
				else
					amide_lab_cell_char="╎"
				fi
				amide_lab_cell_style="$amide_color_scan"
			fi
		fi
	fi

	trace_index=0
	while [ "$trace_index" -lt 3 ]; do
		case "$trace_index" in
			0) base=$((height * 30 / 100)) ;;
			1) base=$((height * 49 / 100)) ;;
			*) base=$((height * 72 / 100)) ;;
		esac
		wave=$(((x * 2 + frame + trace_index * 7) % 16))
		if [ "$wave" -gt 7 ]; then
			wave=$((15 - wave))
		fi
		trace_y=$((base + (wave - 3) / 2))
		if [ "$y" -eq "$trace_y" ]; then
			if [ $(((x + frame + trace_index * 13) % 41)) -eq 0 ]; then
				amide_lab_cell_char="◆"
				amide_lab_cell_style="$amide_color_warning"
			elif [ $(((x + frame) % 12)) -eq 0 ]; then
				amide_lab_cell_char="•"
				amide_lab_cell_style="$amide_color_primary"
			else
				amide_lab_cell_char="·"
				amide_lab_cell_style="$amide_color_primary"
			fi
		fi
		trace_index=$((trace_index + 1))
	done
}

amide_set_blank_line() {
	amide_content_is_set=1
	amide_content_text=
	amide_content_width=0
	amide_content_style=
}

amide_set_text_line() {
	max_width=$((amide_screen_cols - 4))
	if [ "$max_width" -lt 1 ]; then
		max_width=1
	fi
	amide_content_text=$(amide_fit_ascii "$1" "$max_width")
	amide_content_width=${#amide_content_text}
	amide_content_style="$2"
	amide_content_is_set=1
}

amide_set_title_line() {
	max_width=$((amide_screen_cols - 4))
	if [ "$max_width" -lt 1 ]; then
		max_width=1
	fi
	amide_content_text=$(amide_fit_ascii "$1" "$max_width")
	amide_content_width=${#amide_content_text}
	case "$amide_content_text" in
		*"AMIDE"*)
			amide_content_text=$(amide_style_amide_title "$amide_content_text")
			amide_content_style=
			;;
		*)
			amide_content_style="$amide_bold$amide_color_primary"
			;;
	esac
	amide_content_is_set=1
}

amide_style_amide_title() {
	text="$1"
	styled=
	while :; do
		case "$text" in
			*"AMIDE"*)
				before=${text%%AMIDE*}
				rest=${text#*AMIDE}
				styled="${styled}${amide_bold}${amide_color_primary}${before}"
				styled="${styled}${amide_bold}${amide_color_primary}AMIDE${amide_reset}"
				text="$rest"
				;;
			*)
				styled="${styled}${amide_bold}${amide_color_primary}${text}${amide_reset}"
				printf '%s' "$styled"
				return
				;;
		esac
	done
}

amide_fit_ascii() {
	text="$1"
	max_width="$2"
	if [ "${#text}" -le "$max_width" ]; then
		printf '%s' "$text"
		return
	fi
	if [ "$max_width" -le 3 ]; then
		printf '%s' "$text" | cut -c 1-"$max_width"
		return
	fi
	cut_width=$((max_width - 3))
	printf '%s...' "$(printf '%s' "$text" | cut -c 1-"$cut_width")"
}

amide_print_centered_line() {
	text="$1"
	width="$2"
	style="$3"
	left=$(((amide_screen_cols - width) / 2))
	if [ "$left" -lt 0 ]; then
		left=0
	fi
	if [ -n "$style" ]; then
		printf '%*s%s%s%s%s\n' "$left" "" "$style" "$text" "$amide_reset" "$amide_clear_line"
	else
		printf '%*s%s%s\n' "$left" "" "$text" "$amide_clear_line"
	fi
}

amide_place_prompt_cursor() {
	max_width=$((amide_screen_cols - 4))
	if [ "$max_width" -lt 1 ]; then
		max_width=1
	fi
	prompt_text=$(amide_fit_ascii "$(amide_screen_primary_text)" "$max_width")
	prompt_width=${#prompt_text}
	content_height=$(amide_content_height)
	top=$(((amide_screen_rows - content_height) / 2))
	if [ "$top" -lt 0 ]; then
		top=0
	fi
	prompt_index=0
	if amide_show_logo; then
		prompt_index=$((prompt_index + 15))
	fi
	row=$((top + prompt_index + 1))
	col=$(((amide_screen_cols - prompt_width) / 2 + prompt_width + 2))
	if [ "$col" -lt 1 ]; then
		col=1
	fi
	if [ "$col" -gt "$amide_screen_cols" ]; then
		col="$amide_screen_cols"
	fi
	if ( : <>/dev/tty ) 2>/dev/null; then
		printf '%s%s%s[%s;%sH' "$amide_reset" "$amide_show_cursor" "$amide_esc" "$row" "$col" >/dev/tty
	else
		printf '%s%s%s[%s;%sH' "$amide_reset" "$amide_show_cursor" "$amide_esc" "$row" "$col" >&2
	fi
}

amide_pulse() {
	case $((amide_screen_frame % 4)) in
		0) printf '.' ;;
		1) printf '..' ;;
		2) printf '...' ;;
		*) printf '' ;;
	esac
}

amide_animation_detail_count() {
	details="$1"
	case "$details" in
		*'
'*) printf '%s\n' "$details" | wc -l | tr -d ' ' ;;
		*) printf '1' ;;
	esac
}

amide_animation_current_frame() {
	frame="${amide_animation_frame:-1}"
	case "$frame" in
		""|*[!0-9]*) frame=1 ;;
	esac
	if [ "$frame" -lt 1 ]; then
		frame=1
	fi
	printf '%s' "$frame"
}

amide_animation_step_index() {
	details="$1"
	detail_count=$(amide_animation_detail_count "$details")
	frame=$(amide_animation_current_frame)
	detail_index=$(((frame - 1) / 24 + 1))
	if [ "$detail_index" -gt "$detail_count" ]; then
		detail_index="$detail_count"
	fi
	printf '%s' "$detail_index"
}

amide_static_progress_title() {
	case "$1" in
		*...) printf '%s' "$1" ;;
		*) printf '%s...' "$1" ;;
	esac
}

amide_animation_status() {
	status="$1"
	details="$2"
	status_mode="$3"
	case "$status_mode" in
		static) amide_static_progress_title "$status" ;;
		*) printf '%s%s' "$status" "$(amide_pulse)" ;;
	esac
}

amide_animation_detail() {
	details="$1"
	case "$details" in
		*'
'*)
			detail_index=$(amide_animation_step_index "$details")
			printf '%s\n' "$details" | sed -n "${detail_index}p"
			;;
		*) printf '%s' "$details" ;;
	esac
}

amide_run_quiet_with_animation() {
	title="$1"
	status="$2"
	detail="$3"
	shift 3

	amide_run_quiet_with_animation_command "$title" "$status" "$detail" pulse "$@"
}

amide_run_quiet_with_animation_steps() {
	title="$1"
	status="$2"
	details="$3"
	shift 3

	amide_run_quiet_with_animation_command "$title" "$status" "$details" static "$@"
}

amide_run_quiet_with_animation_command() {
	title="$1"
	status="$2"
	details="$3"
	status_mode="$4"
	shift 4

	if [ "$amide_screen_enabled" != 1 ]; then
		printf '%s\n' "$status" >&2
		"$@"
		return
	fi

	output_dir=$(create_temp_dir)
	output_file="$output_dir/output"
	"$@" >"$output_file" 2>&1 &
	command_pid=$!
	amide_animation_frame=0

	while kill -0 "$command_pid" 2>/dev/null; do
		amide_animation_frame=$((amide_animation_frame + 1))
		status_display=$(amide_animation_status "$status" "$details" "$status_mode")
		amide_screen "$title" "$status_display" "$(amide_animation_detail "$details")" ""
		sleep 0.18
	done

	if wait "$command_pid"; then
		command_status=0
	else
		command_status=$?
	fi

	if [ "$command_status" -ne 0 ] && [ -s "$output_file" ]; then
		amide_restore_terminal
		printf '\n' >&2
		cat "$output_file" >&2
	fi
	rm -rf "$output_dir"
	return "$command_status"
}

amide_prompt_yes_no() {
	question="$1"
	detail="$2"
	input_prompt="$3"

	if ( : <>/dev/tty ) 2>/dev/null; then
		prompt_input=tty
		exec 3<>/dev/tty
	elif [ -t 0 ]; then
		prompt_input=stdin
	else
		return 2
	fi

	if [ "$amide_screen_enabled" = 1 ]; then
		amide_screen "$question" "" "$detail" "$input_prompt"
		amide_place_prompt_cursor "$input_prompt"
	else
		printf '%s\n' "$detail"
		if [ "$prompt_input" = tty ]; then
			printf '%s ' "$input_prompt" >&3
		else
			printf '%s ' "$input_prompt" >&2
		fi
	fi

	if [ "$prompt_input" = tty ]; then
		if ! IFS= read -r answer <&3; then
			answer=
		fi
		exec 3>&-
	else
		if ! IFS= read -r answer; then
			answer=
		fi
	fi

	case "$answer" in
		n|N|no|NO)
			return 1
			;;
	esac
	return 0
}

start_preflight_checks() {
	preflight_dir=$(create_temp_dir)
	preflight_file="$preflight_dir/preflight"
	run_preflight_checks >"$preflight_file" &
	preflight_pid=$!
}

finish_preflight_checks() {
	if [ "$amide_screen_enabled" = 1 ]; then
		while kill -0 "$preflight_pid" 2>/dev/null; do
			amide_screen "Checking Node.js and npm$(amide_pulse)" "" "" ""
			sleep 0.18
		done
	fi

	if wait "$preflight_pid"; then
		preflight_status=0
	else
		preflight_status=$?
	fi

	if [ "$amide_screen_enabled" = 1 ]; then
		if [ "$preflight_status" -ne 0 ]; then
			preflight_summary=$(sed -n '1p' "$preflight_file")
			amide_screen "Node.js 20.6.0 or newer is required" "" "$preflight_summary" ""
			sleep 0.4
		elif [ -s "$preflight_file" ]; then
			preflight_summary="Existing $amide_cmd command found on PATH."
			amide_screen "Environment ready" "" "$preflight_summary" ""
			sleep 0.4
		fi
	else
		cat "$preflight_file"
	fi
	rm -rf "$preflight_dir"
	return "$preflight_status"
}

run_preflight_checks() {
	status=0
	yellow="${amide_esc}[33m"
	reset="${amide_esc}[0m"

	if command -v node >/dev/null 2>&1; then
		node_version=$(node --version)
		if ! node -e 'const [major, minor, patch] = process.versions.node.split(".").map(Number); process.exit(major > 20 || (major === 20 && (minor > 6 || (minor === 6 && patch >= 0))) ? 0 : 1)' >/dev/null; then
			printf 'error: AMIDE requires Node.js 20.6.0 or newer. Found %s.\n' "$node_version"
			status=1
		fi
	else
		printf 'error: Node.js 20.6.0 or newer is required to install AMIDE.\n'
		status=1
	fi

	if ! command -v npm >/dev/null 2>&1; then
		printf 'error: npm is required to install AMIDE.\n'
		status=1
	fi

	if [ "$status" -ne 0 ]; then
		printf '\n'
	fi

	if amide_path=$(command -v "$amide_cmd" 2>/dev/null); then
		printf '%sExisting %s found at: %s%s\n' "$yellow" "$amide_cmd" "$amide_path" "$reset"
		printf '\n'
	fi

	return "$status"
}

resolve_amide_version() {
	if [ "${1:-}" ]; then
		case "$1" in
			stable|beta) release_channel="$1" ;;
			*)
				normalize_version "$1"
				return
				;;
		esac
	else
		release_channel="$amide_release_channel"
	fi

	if [ "${AMIDE_VERSION:-}" ]; then
		normalize_version "$AMIDE_VERSION"
		return
	fi

	if ! command -v curl >/dev/null 2>&1; then
		printf 'error: curl is required to resolve the latest AMIDE version.\n' >&2
		exit 1
	fi

	case "$release_channel" in
		stable|beta) ;;
		*)
			printf 'error: invalid AMIDE release channel: %s\n' "$release_channel" >&2
			exit 1
			;;
	esac

	channel_dir=$(create_temp_dir)
	channel_path="$channel_dir/$release_channel"
	if ! amide_run_quiet_with_animation \
		"Resolving latest release" \
		"Resolving latest release" \
		"Checking the $release_channel release channel." \
		curl -fsSL "$amide_base_url/$release_channel" -o "$channel_path"; then
		rm -rf "$channel_dir"
		printf 'error: could not resolve latest AMIDE version from %s/%s\n' "$amide_base_url" "$release_channel" >&2
		exit 1
	fi
	channel_version="$(tr -d '[:space:]' <"$channel_path")"
	rm -rf "$channel_dir"
	if [ -z "$channel_version" ]; then
		printf 'error: could not resolve latest AMIDE version from %s/%s\n' "$amide_base_url" "$release_channel" >&2
		exit 1
	fi
	normalize_version "$channel_version"
}

normalize_version() {
	version="${1#v}"
	case "$version" in
		"")
			printf 'error: empty AMIDE version.\n' >&2
			exit 1
			;;
		*[!0-9A-Za-z.-]*)
			printf 'error: invalid AMIDE version: %s\n' "$1" >&2
			exit 1
			;;
	esac
	printf '%s' "$version"
}

install_node_npm_interactive() {
	method=$(detect_node_install_method)
	case "$method" in
		homebrew) label="Homebrew" ;;
		apt) label="apt" ;;
		apk) label="apk" ;;
		standalone) label="standalone Node.js" ;;
		*)
			method=standalone
			label="standalone Node.js"
			;;
	esac

	if amide_prompt_yes_no \
		"Install Node.js and npm with $label?" \
		"Required before AMIDE can be installed." \
		"Install? [Y/n]"; then
		install_node_npm "$method" "$label"
		return
	else
		prompt_status=$?
	fi
	if [ "$prompt_status" -eq 2 ]; then
		printf 'No terminal detected; install Node.js 20.6.0 or newer and npm, then run this installer again.\n'
	else
		printf '\nInstall Node.js 20.6.0 or newer and npm, then run this installer again.\n'
	fi
	return 1
}

detect_node_install_method() {
	case "$(uname -s)" in
		Darwin)
			if command -v brew >/dev/null 2>&1; then
				printf 'homebrew'
			else
				printf 'standalone'
			fi
			;;
		Linux)
			if command -v apt-cache >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1 && apt_node_candidate_is_new_enough; then
				printf 'apt'
			elif command -v apk >/dev/null 2>&1 && apk_node_candidate_is_new_enough; then
				printf 'apk'
			else
				printf 'standalone'
			fi
			;;
		*)
			printf 'standalone'
			;;
	esac
}

apt_node_candidate_is_new_enough() {
	version=$(apt-cache policy nodejs 2>/dev/null | awk '/Candidate:/ { print $2; exit }')
	[ -n "$version" ] && [ "$version" != "(none)" ] && node_version_string_is_new_enough "$version"
}

apk_node_candidate_is_new_enough() {
	version=$(apk search -x nodejs 2>/dev/null | awk -F- '/^nodejs-/ { print $2; exit }')
	[ -n "$version" ] && node_version_string_is_new_enough "$version"
}

node_version_string_is_new_enough() {
	version="${1#v}"
	case "$version" in
		[0-9]*) ;;
		*) return 1 ;;
	esac
	version="${version%%[!0-9.]*}"
	version_ifs=${IFS- }
	IFS=.
	set -- $version
	IFS=$version_ifs
	major="${1:-}"
	minor="${2:-0}"
	patch="${3:-0}"
	case "$major" in ''|*[!0-9]*) return 1 ;; esac
	case "$minor" in ''|*[!0-9]*) minor=0 ;; esac
	case "$patch" in ''|*[!0-9]*) patch=0 ;; esac

	[ "$major" -gt 20 ] && return 0
	[ "$major" -eq 20 ] && [ "$minor" -gt 6 ] && return 0
	[ "$major" -eq 20 ] && [ "$minor" -eq 6 ] && [ "$patch" -ge 0 ] && return 0
	return 1
}

install_node_npm() {
	method="$1"
	label="$2"

	if [ "$amide_screen_enabled" != 1 ]; then
		printf '\nInstalling Node.js and npm with %s...\n\n' "$label"
		run_node_install_method "$method"
	else
		prepare_sudo_for_node_install "$method"
		node_install_details="Using $label.
Resolving Node.js packages.
Downloading Node.js runtime.
Installing npm.
Preparing AMIDE setup."
		amide_run_quiet_with_animation_steps \
			"Installing Node.js and npm" \
			"Installing Node.js and npm" \
			"$node_install_details" \
			run_node_install_method "$method"
	fi

	if [ "$method" = standalone ]; then
		load_standalone_node
		AMIDE_NODE_INSTALLED_STANDALONE=1
	fi
	hash -r
	if [ "$amide_screen_enabled" = 1 ]; then
		amide_screen "Node.js and npm installed" "" "Continuing AMIDE setup." ""
	else
		printf '\nNode.js and npm are installed.\n\n'
	fi
}

node_install_needs_sudo() {
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		return 1
	fi

	case "$1" in
		apt|apk)
			return 0
			;;
		standalone)
			[ "$(uname -s)" = Linux ] || return 1
			command -v xz >/dev/null 2>&1 && return 1
			command -v apt-get >/dev/null 2>&1 || command -v apk >/dev/null 2>&1
			;;
		*)
			return 1
			;;
	esac
}

prepare_sudo_for_node_install() {
	method="$1"
	if ! node_install_needs_sudo "$method"; then
		return 0
	fi

	amide_screen "Preparing Node.js install" "" "This may ask for your sudo password." ""
	amide_restore_terminal
	printf '\n'
	sudo -v
}

run_node_install_method() {
	case "$1" in
		homebrew) install_node_with_homebrew ;;
		apt) install_node_with_apt ;;
		apk) install_node_with_apk ;;
		standalone) install_node_standalone ;;
	esac
}

install_node_with_homebrew() {
	if brew list node >/dev/null 2>&1; then
		brew upgrade node
	else
		brew install node
	fi
}

install_node_with_apt() {
	print_sudo_note
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		apt-get update
		apt-get install -y nodejs npm
	else
		sudo sh -c 'apt-get update && apt-get install -y nodejs npm'
	fi
}

install_node_with_apk() {
	print_sudo_note
	run_with_sudo apk add --update-cache nodejs npm
}

install_node_standalone() {
	node_platform=$(detect_node_binary_platform) || {
		printf 'Unsupported operating system for automatic Node.js install: %s\n' "$(uname -s)"
		return 1
	}
	node_arch=$(detect_node_binary_arch) || {
		printf 'Unsupported CPU architecture for automatic Node.js install: %s\n' "$(uname -m)"
		return 1
	}
	node_dist_base="https://nodejs.org/dist/latest-v22.x"
	node_base_dir=$(node_standalone_base_dir)
	node_tmp_dir=$(create_temp_dir)

	mkdir -p "$node_tmp_dir" "$node_base_dir"

	printf 'Resolving Node.js binary for %s-%s\n' "$node_platform" "$node_arch"
	curl -fsSL "$node_dist_base/SHASUMS256.txt" -o "$node_tmp_dir/SHASUMS256.txt"
	node_file=$(awk -v suffix="-$node_platform-$node_arch.tar.xz" '
		index($2, "node-v") == 1 && length($2) >= length(suffix) && substr($2, length($2) - length(suffix) + 1) == suffix { print $2; exit }
	' "$node_tmp_dir/SHASUMS256.txt")
	if [ -z "$node_file" ]; then
		printf 'No Node.js binary is available for %s-%s.\n' "$node_platform" "$node_arch"
		rm -rf "$node_tmp_dir"
		return 1
	fi
	case "$node_file" in
		*/*|*\\*|*..*)
			printf 'Unsafe Node.js archive name in checksum manifest: %s\n' "$node_file"
			rm -rf "$node_tmp_dir"
			return 1
			;;
		node-v*-"$node_platform"-"$node_arch".tar.xz) ;;
		*)
			printf 'Unexpected Node.js archive name in checksum manifest: %s\n' "$node_file"
			rm -rf "$node_tmp_dir"
			return 1
			;;
	esac

	printf 'Downloading Node.js %s\n' "${node_file%.tar.xz}"
	curl -fsSL "$node_dist_base/$node_file" -o "$node_tmp_dir/$node_file"
	verify_node_standalone_download "$node_tmp_dir" "$node_file"
	ensure_node_standalone_extract_tools "$node_platform"

	node_dir="$node_base_dir/${node_file%.tar.xz}"
	rm -rf "$node_dir"
	printf 'Extracting Node.js to %s\n' "$node_dir"
	tar -xf "$node_tmp_dir/$node_file" -C "$node_base_dir"
	rm -f "$node_base_dir/current"
	ln -s "$node_dir" "$node_base_dir/current"
	rm -rf "$node_tmp_dir"
	printf 'Node.js installed at %s\n' "$node_dir"
}

verify_node_standalone_download() {
	checksum_dir="$1"
	checksum_file_name="$2"
	awk -v file="$checksum_file_name" '$2 == file { print }' "$checksum_dir/SHASUMS256.txt" >"$checksum_dir/SHASUMS256.selected"

	if command -v sha256sum >/dev/null 2>&1; then
		printf 'Verifying Node.js download\n'
		(cd "$checksum_dir" && sha256sum -c SHASUMS256.selected)
	elif command -v shasum >/dev/null 2>&1; then
		printf 'Verifying Node.js download\n'
		(cd "$checksum_dir" && shasum -a 256 -c SHASUMS256.selected)
	else
		printf 'error: sha256sum or shasum is required to verify the Node.js download.\n'
		return 1
	fi
}

ensure_node_standalone_extract_tools() {
	extract_platform="$1"

	if [ "$extract_platform" = linux ] && ! command -v xz >/dev/null 2>&1; then
		printf 'Installing xz-utils for Node.js archive extraction\n'
		print_sudo_note
		if command -v apt-get >/dev/null 2>&1; then
			run_with_sudo apt-get update
			run_with_sudo apt-get install -y xz-utils
		elif command -v apk >/dev/null 2>&1; then
			run_with_sudo apk add --update-cache xz
		else
			printf 'xz is required to extract Node.js. Install xz and run this installer again.\n'
			return 1
		fi
	fi
}

load_standalone_node() {
	AMIDE_STANDALONE_NODE_BIN="$(node_standalone_base_dir)/current/bin"
	PATH="$AMIDE_STANDALONE_NODE_BIN:$PATH"
	export AMIDE_STANDALONE_NODE_BIN PATH
}

node_standalone_base_dir() {
	if [ -n "${XDG_DATA_HOME:-}" ]; then
		printf '%s/amide-node' "$XDG_DATA_HOME"
	else
		printf '%s/.local/share/amide-node' "$HOME"
	fi
}

detect_node_binary_platform() {
	case "$(uname -s)" in
		Darwin) printf 'darwin' ;;
		Linux) printf 'linux' ;;
		*) return 1 ;;
	esac
}

detect_node_binary_arch() {
	case "$(uname -m)" in
		x86_64|amd64) printf 'x64' ;;
		arm64|aarch64) printf 'arm64' ;;
		armv7l) printf 'armv7l' ;;
		ppc64le) printf 'ppc64le' ;;
		s390x) printf 's390x' ;;
		*) return 1 ;;
	esac
}

print_sudo_note() {
	if [ "${EUID:-$(id -u)}" -ne 0 ]; then
		printf 'This may ask for your sudo password.\n\n'
	fi
}

run_with_sudo() {
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		"$@"
	else
		sudo "$@"
	fi
}

configure_standalone_node_path() {
	if original_amide_path=$(resolve_amide_with_original_path); then
		case "$original_amide_path" in
			"$AMIDE_STANDALONE_NODE_BIN/"*)
				if [ "$amide_screen_enabled" = 1 ]; then
					amide_screen "AMIDE installed" "" "Run it with: $amide_cmd" ""
				else
					printf '\nRun it with: %s\n' "$amide_cmd"
				fi
				return 0
				;;
		esac
		if [ "$amide_screen_enabled" = 1 ]; then
			amide_screen "AMIDE installed" "" "PATH update needed for $amide_cmd." ""
		else
			printf '%s was installed, but your shell is not using that install yet.\n' "$amide_cmd"
			printf 'Your shell currently resolves %s to: %s\n' "$amide_cmd" "$original_amide_path"
		fi
	else
		if [ "$amide_screen_enabled" = 1 ]; then
			amide_screen "AMIDE installed" "" "PATH update needed for $amide_cmd." ""
		else
			printf '%s was installed, but your shell is not using that install yet.\n' "$amide_cmd"
		fi
	fi

	profile=$(detect_shell_profile) || {
		if [ "$amide_screen_enabled" = 1 ]; then
			amide_restore_terminal
			printf '\n'
		fi
		print_standalone_path_manual_instructions
		return 0
	}

	if shell_profile_has_standalone_node_path "$profile"; then
		if [ "$amide_screen_enabled" = 1 ]; then
			amide_screen "AMIDE installed" "" "Run: $(amide_source_profile_command "$profile")" ""
		else
			printf '%s already contains %s.\n' "$profile" "$AMIDE_STANDALONE_NODE_BIN"
			printf 'Restart your shell or run: %s\n' "$(amide_source_profile_command "$profile")"
		fi
		return 0
	fi

	prompt_add_standalone_node_path "$profile"
}

resolve_amide_with_original_path() {
	saved_path=$PATH
	PATH=$amide_original_path
	if command -v "$amide_cmd" 2>/dev/null; then
		status=0
	else
		status=$?
	fi
	PATH=$saved_path
	return "$status"
}

detect_shell_profile() {
	if [ -n "${AMIDE_SHELL_PROFILE:-}" ]; then
		printf '%s' "$AMIDE_SHELL_PROFILE"
		return 0
	fi
	if [ -z "${HOME:-}" ]; then
		return 1
	fi

	shell_name="${SHELL:-}"
	shell_name="${shell_name##*/}"
	case "$shell_name" in
		zsh)
			printf '%s/.zshrc' "${ZDOTDIR:-$HOME}"
			;;
		bash)
			printf '%s/.bashrc' "$HOME"
			;;
		*)
			if [ -f "$HOME/.zshrc" ]; then
				printf '%s/.zshrc' "$HOME"
			elif [ -f "$HOME/.bashrc" ]; then
				printf '%s/.bashrc' "$HOME"
			else
				printf '%s/.profile' "$HOME"
			fi
			;;
	esac
}

shell_profile_has_standalone_node_path() {
	profile="$1"
	[ -f "$profile" ] && grep -F "$AMIDE_STANDALONE_NODE_BIN" "$profile" >/dev/null 2>&1
}

prompt_add_standalone_node_path() {
	profile="$1"
	path_line=$(standalone_node_path_line)

	if ! amide_prompt_yes_no \
		"Add standalone Node.js to your PATH?" \
		"Updates $profile so future shells can run $amide_cmd." \
		"Update PATH? [Y/n]"; then
		if [ "$amide_screen_enabled" = 1 ]; then
			amide_restore_terminal
			printf '\n'
		fi
		print_standalone_path_manual_instructions
		return 0
	fi

	mkdir -p "$(dirname "$profile")"
	{
		printf '\n# AMIDE standalone Node.js\n'
		printf '%s\n' "$path_line"
	} >>"$profile"
	if [ "$amide_screen_enabled" = 1 ]; then
		amide_screen "AMIDE installed" "" "Run: $(amide_source_profile_command "$profile")" ""
	else
		printf 'Added %s to %s.\n' "$AMIDE_STANDALONE_NODE_BIN" "$profile"
		printf 'Restart your shell or run: %s\n' "$(amide_source_profile_command "$profile")"
	fi
}

print_standalone_path_manual_instructions() {
	printf 'Add this to your shell profile to use %s from new shells:\n\n' "$amide_cmd"
	printf '  %s\n' "$(standalone_node_path_line)"
	printf '\nThen restart your shell and run: %s\n' "$amide_cmd"
}

standalone_node_path_line() {
	printf 'export PATH="%s:$PATH"' "$AMIDE_STANDALONE_NODE_BIN"
}

amide_shell_quote() {
	quoted=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
	printf "'%s'" "$quoted"
}

amide_source_profile_command() {
	printf '. %s && %s' "$(amide_shell_quote "$1")" "$amide_cmd"
}

download_amide_package() {
	version="$1"
	tarball_url="$2"
	tarball_path="$3"
	download_dir=$(dirname "$tarball_path")
	tarball_name=$(basename "$tarball_path")
	checksums_url="$amide_base_url/releases/v$version/SHA256SUMS"
	checksums_path="$download_dir/SHA256SUMS"

	if ! command -v curl >/dev/null 2>&1; then
		printf 'error: curl is required to download AMIDE.\n' >&2
		exit 1
	fi

	amide_run_quiet_with_animation \
		"Downloading checksums" \
		"Downloading release checksums" \
		"AMIDE v$version" \
		curl -fsSL "$checksums_url" -o "$checksums_path"

	amide_run_quiet_with_animation \
		"Downloading AMIDE" \
		"Downloading AMIDE v$version" \
		"Fetching the verified package." \
		curl -fsSL "$tarball_url" -o "$tarball_path"

	verify_amide_package_checksum "$checksums_path" "$tarball_path"
}

verify_amide_package_checksum() {
	checksums_path="$1"
	tarball_path="$2"
	checksum_dir=$(dirname "$tarball_path")
	tarball_name=$(basename "$tarball_path")
	selected_checksums_path="$checksum_dir/SHA256SUMS.selected"

	if ! awk -v file="$tarball_name" '$2 == file { print; found = 1; exit } END { if (!found) exit 1 }' \
		"$checksums_path" >"$selected_checksums_path"; then
		printf 'error: checksum for %s was not found in %s\n' "$tarball_name" "$checksums_path" >&2
		exit 1
	fi

	if command -v sha256sum >/dev/null 2>&1; then
		amide_run_quiet_with_animation \
			"Verifying download" \
			"Verifying AMIDE download" \
			"Checking SHA-256." \
			amide_run_checksum_check "$checksum_dir" "$(basename "$selected_checksums_path")" sha256sum
	elif command -v shasum >/dev/null 2>&1; then
		amide_run_quiet_with_animation \
			"Verifying download" \
			"Verifying AMIDE download" \
			"Checking SHA-256." \
			amide_run_checksum_check "$checksum_dir" "$(basename "$selected_checksums_path")" shasum
	else
		printf 'error: sha256sum or shasum is required to verify the AMIDE download.\n' >&2
		exit 1
	fi
}

amide_run_checksum_check() {
	checksum_dir="$1"
	selected_checksums_name="$2"
	checker="$3"
	case "$checker" in
		sha256sum)
			(cd "$checksum_dir" && sha256sum -c "$selected_checksums_name")
			;;
		shasum)
			(cd "$checksum_dir" && shasum -a 256 -c "$selected_checksums_name")
			;;
	esac
}

confirm_install() {
	version="$1"
	tarball_url="$2"

	if amide_prompt_yes_no \
		"Install AMIDE v$version globally with npm?" \
		"Downloads the verified release and runs npm install -g." \
		"Install? [Y/n]"; then
		return 0
	else
		prompt_status=$?
	fi

	if [ "$prompt_status" -eq 2 ]; then
		printf 'This will download, verify, and install:\n\n  %s\n\n' "$tarball_url"
		printf 'No terminal detected; continuing without confirmation.\n'
		return 0
	fi

	if [ "$amide_screen_enabled" = 1 ]; then
		amide_screen "Installation cancelled" "" "No changes were made." ""
		exit 0
	fi
	printf '\nInstallation cancelled.\n'
	exit 0
}

confirm_kernel_runtime_setup() {
	case "${AMIDE_BOOTSTRAP_KERNEL_ON_INSTALL:-}" in
		1)
			amide_bootstrap_kernel_on_install=1
			return
			;;
		0)
			amide_bootstrap_kernel_on_install=0
			return
			;;
	esac

	if amide_prompt_yes_no \
		"Prepare Python runtime now?" \
		"Installs uv, Python 3.11, and the AMIDE runtime." \
		"Prepare? [Y/n]"; then
		amide_bootstrap_kernel_on_install=1
		return
	else
		prompt_status=$?
	fi

	if [ "$prompt_status" -eq 2 ]; then
		printf 'No terminal detected; preparing the Python runtime during install.\n'
		amide_bootstrap_kernel_on_install=1
		return
	fi

	amide_bootstrap_kernel_on_install=0
	if [ "$amide_screen_enabled" = 1 ]; then
		amide_screen "Python setup skipped" "" "The runtime can be prepared on first ipython use." ""
		sleep 0.4
	else
		printf '\nSkipping Python runtime setup.\n'
	fi
}

amide_npm_requires_remote_policy() {
	npm_version=$(npm --version 2>/dev/null) || return 1
	npm_major=${npm_version%%.*}
	case "$npm_major" in
		""|*[!0-9]*) return 1 ;;
	esac
	[ "$npm_major" -ge 12 ]
}

amide_npm_install() {
	tarball_path="$1"
	shift
	if amide_npm_requires_remote_policy; then
		# Limit npm 12's required policy overrides to the verified root package.
		env "$@" npm install -g --no-fund --no-audit --loglevel=error --progress=false \
			--allow-remote=all --allow-scripts="$tarball_path" "$tarball_path"
	else
		env "$@" npm install -g --no-fund --no-audit --loglevel=error --progress=false "$tarball_path"
	fi
}

install_amide_package() {
	tarball_path="$1"
	if [ "$amide_bootstrap_kernel_on_install" = 1 ]; then
		npm_install_details="Preparing global install.
Linking command binaries.
Installing runtime packages.
Preloading search tools.
Preparing Python kernel.
Finalizing npm install."
		amide_run_quiet_with_animation_steps \
			"Installing AMIDE" \
			"Installing AMIDE" \
			"$npm_install_details" \
			amide_npm_install "$tarball_path" AMIDE_BOOTSTRAP_TOOLS_ON_INSTALL=1 AMIDE_BOOTSTRAP_KERNEL_ON_INSTALL=1 AMIDE_INSTALL_UV=1
	else
		npm_install_details="Preparing global install.
Linking command binaries.
Installing runtime packages.
Preloading search tools.
Finalizing npm install."
		amide_run_quiet_with_animation_steps \
			"Installing AMIDE" \
			"Installing AMIDE" \
			"$npm_install_details" \
			amide_npm_install "$tarball_path" AMIDE_BOOTSTRAP_TOOLS_ON_INSTALL=1
	fi
}

main "$@"
