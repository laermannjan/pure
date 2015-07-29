# name: Pure
# ---------------
# Pure for fish
# by Vlad Kovtash
# MIT License
# ---------------
# Configuration variables
#
# PURE_CMD_MAX_EXEC_TIME    The max execution time of a process before its run time is shown 
#                           when it exits. Defaults to 5 seconds.
#
# PURE_GIT_FETCH            Set PURE_GIT_FETCH=0 to prevent Pure from checking whether the current 
#                           Git remote has been updated.
#
# PURE_GIT_FETCH_INTERVAL   Interval to check current Git remote for changes. 
#                           Defaults to 1800 seconds.
#
# PURE_PROMPT_SYMBOL        Defines the prompt symbol. The default value is ❯.    
#                       
# PURE_GIT_UP_ARROW         Defines the git up arrow symbol. The default value is ⇡.
#
# PURE_GIT_DOWN_ARROW       Defines the git down arrow symbol. The default value is ⇣.
#
# PURE_GIT_FETCH_INDICATOR  Defines the git fetch proxess indicator symbol. The default value is ⇣.
#
#


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
  else
    return 0
  end
end;


function _pure_timestamp
  command date +%s
end


function _pure_cmd_max_exec_time;   _pure_get_var PURE_CMD_MAX_EXEC_TIME 5; end;
function _pure_prompt_symbol;       _pure_get_var PURE_PROMPT_SYMBOL "❯"; end;
function _pure_git_up_arrow;        _pure_get_var PURE_GIT_UP_ARROW "⇡"; end;
function _pure_git_down_arrow;      _pure_get_var PURE_GIT_DOWN_ARROW "⇣"; end;
function _pure_git_fetch_indicator; _pure_get_var PURE_GIT_FETCH_INDICATOR "⇣"; end;
function _pure_git_fetch_interval;  _pure_get_var PURE_GIT_FETCH_INTERVAL 1800; end;


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


function _pure_git_async_fetch
  if not _pure_git_fetch_allowed
    return 0
  end
  
  if set -q _pure_git_async_fetch_running
   return 0
  end
  
  set -l working_tree $argv[1]
  pushd $working_tree
  
  if [ ! (command git rev-parse --abbrev-ref @'{u}' ^ /dev/null) ]
    popd
    return 0
  end

  set -l git_fetch_required no
  if [ ! -e .git/FETCH_HEAD ]
    set git_fetch_required yes
  else
    set last_fetch_timestamp (command stat -f "%m" .git/FETCH_HEAD)
    set current_timestamp (_pure_timestamp)
    set -l time_since_last_fetch (math "$current_timestamp - $last_fetch_timestamp")
    if [ $time_since_last_fetch -gt (_pure_git_fetch_interval) ]
      set git_fetch_required yes
    end
  end

  if [ $git_fetch_required = no ]
    popd
    return 0
  end

  set -g _pure_git_async_fetch_running
  
  env GIT_TERMINAL_PROMPT=0 command git -c gc.auto=0 fetch > /dev/null ^ /dev/null &

  set -l job (jobs -l -p)
  
  popd
  
  function _notify_job_$job --on-process-exit $job --inherit-variable job
    set -e _pure_git_async_fetch_running
    functions -e _notify_job_$job
    kill -WINCH %self
  end
end


function _pure_git_arrows
  set -l working_tree $argv[1]
  pushd $working_tree
  
  if [ ! (command git rev-parse --abbrev-ref @'{u}' ^ /dev/null) ]
    popd
    return 0
  end
      
  set -l left (command git rev-list --left-only --count HEAD...@'{u}' ^ /dev/null)      
  set -l right (command git rev-list --right-only --count HEAD...@'{u}' ^ /dev/null)

  popd

  if [ $left -eq 0 -a $right -eq 0 ]
    return 0
  end

  set -l arrows ""

  if [ $left -gt 0 ]
    set arrows $arrows(_pure_git_up_arrow)
  end

  if [ $right -gt 0 ]
    set arrows $arrows(_pure_git_down_arrow)
  end
  
  echo $arrows
end


function _pure_git_info
  set -l working_tree $argv[1]
  
  pushd $working_tree
  set -l git_branch_name (command git symbolic-ref HEAD ^/dev/null | sed -e 's|^refs/heads/||')
  set -l git_dirty_files_count (command git status -unormal --porcelain --ignore-submodules ^/dev/null | wc -l)
  popd
  
  if test -n $git_branch_name
    set -l git_dirty_mark
    if test $git_dirty_files_count -gt 0
      set git_dirty_mark "*"
    end
    echo -n -s $git_branch_name $git_dirty_mark
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

  if [ \( $uid -eq 0 -o $SUDO_USER \) -o $SSH_CONNECTION ]
    echo -n -s $white $USER $gray "@" (command hostname | command cut -f 1 -d ".") " " $normal
  end
 
  # Print pwd or full path
  echo -n -s $cwd $normal
  
  # Print last command duration
  set -l cmd_duration (_pure_cmd_duration)
  
  if [ $cmd_duration ]
   echo -n -s $yellow " " $cmd_duration $normal
  end

  set -l git_working_tree (command git rev-parse --show-toplevel ^/dev/null)

  # Show git branch an status
  if [ $git_working_tree ]
    _pure_git_async_fetch $git_working_tree

    set -l git_info (_pure_git_info $git_working_tree)
    if [ $git_info ]
      echo -n -s $gray " " $git_info $normal
    end
    
    set -l git_arrows (_pure_git_arrows $git_working_tree)
    if [ $git_arrows ]
      echo -n -s $cyan " " $git_arrows $normal
    end

    if set -q _pure_git_async_fetch_running
      echo -n -s $green " " (_pure_git_fetch_indicator) $normal
    else
      echo -n -s "  "
    end
  end

  set prompt_color $magenta
  if [ $last_status != 0 ]
    set prompt_color $red
  end

  # Terminate with a nice prompt char
  echo -e ''
  echo -e -n -s $prompt_color (_pure_prompt_symbol) " " $normal
end
