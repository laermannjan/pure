# name: Pure
# ---------------
# Pure for fish
# by Vlad Kovtash
# MIT License
# ---------------
# Configuration variables
#
# PURE_CMD_MAX_EXEC_TIME        The max execution time of a process before its run time is shown
#                               when it exits. Defaults to 5 seconds.
#
# PURE_GIT_FETCH                Set PURE_GIT_FETCH=0 to prevent Pure from checking whether
#                               the current Git remote has been updated.
#
# PURE_GIT_FETCH_INTERVAL       Interval to check current Git remote for changes.
#                               Defaults to 1800 seconds.
# PURE_GIT_DIRTY_CHECK_INTERVAL Interval to check current Git remote for changes.
#                               Defaults to 10 seconds.
#
# PURE_PROMPT_SYMBOL            Defines the prompt symbol. The default value is ❯.
#
# PURE_GIT_UP_ARROW             Defines the git up arrow symbol. The default value is ⇡.
#
# PURE_GIT_DOWN_ARROW           Defines the git down arrow symbol. The default value is ⇣.
#
# PURE_GIT_FETCH_INDICATOR      Defines the git fetch proxess indicator symbol.
#                               The default value is •.
#
# PURE_ASYNC_TASK               Indicates that current fish instance is created by pure and running
#                               background async task.
#

# Disable virtualenv fish prompt. Pure will handle virtualenv by itself
set -gx VIRTUAL_ENV_DISABLE_PROMPT 1


function _pure_get_var
    set -l var_name $argv[1]
    set -l var_default_value $argv[2]
    if not set -q $var_name
        set -U $var_name $var_default_value
    end
    echo $$var_name
end


function _pure_git_fetch_allowed
    if [ (_pure_get_var PURE_GIT_FETCH 1) = 0 ]
        return 1
    end
    return 0
end;


function _pure_timestamp
    command date +%s
end


function _pure_cmd_max_exec_time;           _pure_get_var PURE_CMD_MAX_EXEC_TIME 5; end;
function _pure_prompt_symbol;               _pure_get_var PURE_PROMPT_SYMBOL "❯"; end;
function _pure_git_up_arrow;                _pure_get_var PURE_GIT_UP_ARROW "⇡"; end;
function _pure_git_down_arrow;              _pure_get_var PURE_GIT_DOWN_ARROW "⇣"; end;
function _pure_git_fetch_indicator;         _pure_get_var PURE_GIT_FETCH_INDICATOR "•"; end;
function _pure_git_fetch_interval;          _pure_get_var PURE_GIT_FETCH_INTERVAL 1800; end;
function _pure_git_dirty_check_interval;    _pure_get_var PURE_GIT_DIRTY_CHECK_INTERVAL 10; end;


function _pure_update_prompt
    #Don't know why, but calling kill -WINCH directly has no effect
    set -l cmd "kill -WINCH "(echo %self)
    fish -c "$cmd" &
end


function _pure_cmd_duration
    set -l duration 0
    if [ $CMD_DURATION ]
        set duration $CMD_DURATION
    end

    set full_seconds (math "$duration / 1000")
    set second_parts (math "$duration % 1000 / 10")
    set seconds (math "$full_seconds % 60")
    set minutes (math "$full_seconds / 60 % 60")
    set hours (math "$full_seconds / 60 / 60 % 24")
    set days (math "$full_seconds / 60/ 60 /24")

    if [ $days -gt 0 ]
        echo -n -s $days "d "
    end

    if [ $hours -gt 0 ]
        echo -n -s $hours "h "
    end

    if [ $minutes -gt 0 ]
        echo -n -s $minutes "m "
    end

    if [ $full_seconds -ge (_pure_cmd_max_exec_time) ]
        echo -s $seconds.$second_parts "s"
    end
end


function fish_prompt
    set last_status $status

    set -l cyan (set_color cyan)
    set -l yellow (set_color yellow)
    set -l red (set_color red)
    set -l blue (set_color blue)
    set -l green (set_color green)
    set -l normal (set_color normal)
    set -l magenta (set_color magenta)
    set -l white (set_color white)
    set -l gray (set_color 666)

    set -l cwd $blue(pwd | sed "s:^$HOME:~:")

    # Output the prompt, left to right

    # Add a newline before new prompts
    echo -e ''

    # Display username and hostname if logged in as root, in sudo or ssh session
    set -l uid (id -u)

    set -l env_description_separator ""

    if [ \( $uid -eq 0 -o $SUDO_USER \) -o $SSH_CONNECTION ]
        echo -n -s $white $USER $gray "@" (command hostname | command cut -f 1 -d ".")
        set env_description_separator " "
    end

    # Display virtualenv name
    if set -q VIRTUAL_ENV
        echo -n -s $gray "(" (command basename "$VIRTUAL_ENV") ")"
        set env_description_separator " "
    end

    # Print pwd or full path
    echo -n -s $normal $env_description_separator $cwd
    # Redraw tail of prompt on winch
    echo -n -s "          "

    set prompt_color $magenta
    if [ $last_status != 0 ]
        set prompt_color $red
    end

    # Terminate with a nice prompt char
    echo -e ''
    echo -e -n -s $prompt_color (_pure_prompt_symbol) " " $normal
end
