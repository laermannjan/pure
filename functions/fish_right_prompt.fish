
function unique_async_job
    set -l job_unique_flag $argv[1]
    set -l callback_function $argv[2]
    set -l cmd $argv[3]

    if set -q $job_unique_flag
        return 0
    end

    set -g $job_unique_flag
    set -l async_job_result _async_job_result_(random)

    set -U $async_job_result "…"


    set -lx PURE_ASYNC_TASK 1
    fish -c "set -U $async_job_result (eval $cmd)" &
    set -l pid (jobs -l -p)

    function _async_job_$pid -v $async_job_result -V pid -V async_job_result -V callback_function -V job_unique_flag
        set -e $job_unique_flag
        eval $callback_function $$async_job_result
        functions -e _async_job_$pid
        set -e $async_job_result
    end
end


function _pure_async_git_fetch
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

    if [ -e .git/FETCH_HEAD ]
        set -l last_fetch_timestamp (command stat -f "%m" .git/FETCH_HEAD)
        set -l current_timestamp (_pure_timestamp)
        set -l time_since_last_fetch (math "$current_timestamp - $last_fetch_timestamp")
        if [ $time_since_last_fetch -gt (_pure_git_fetch_interval) ]
            set git_fetch_required yes
        end
    else
        set git_fetch_required yes
    end

    if [ $git_fetch_required = no ]
        popd
        return 0
    end

    set -l cmd "env GIT_TERMINAL_PROMPT=0 command git -c gc.auto=0 fetch > /dev/null ^ /dev/null"
    unique_async_job "_pure_async_git_fetch_running" _pure_update_prompt $cmd

    popd
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


function _pure_dirty_mark_completion
    set -g _pure_git_last_dirty_check_timestamp (_pure_timestamp)

    set -l dirty_files_count $argv[1]

    if [ $dirty_files_count -gt 0 ]
        set -g _pure_git_is_dirty
    else
        set -e _pure_git_is_dirty
    end

    _pure_update_prompt
end


function _pure_git_info
    if not set -q _pure_git_last_dirty_check_timestamp
        set -g _pure_git_last_dirty_check_timestamp 0
    end

    set -l working_tree $argv[1]
    set -l current_timestamp (_pure_timestamp)
    set -l time_since_last_dirty_check (math "$current_timestamp - $_pure_git_last_dirty_check_timestamp")

    pushd $working_tree
    if [ $time_since_last_dirty_check -gt (_pure_git_dirty_check_interval) ]
        set -l cmd "command git status -unormal --porcelain --ignore-submodules ^/dev/null | wc -l"
        unique_async_job "_pure_async_git_dirty_check_running" _pure_dirty_mark_completion $cmd
    end

    set -l git_branch_name (command git symbolic-ref HEAD ^/dev/null | sed -e 's|^refs/heads/||')

    # handle detached HEAD
    if [ -z $git_branch_name ]
        set git_branch_name (command git rev-parse --short HEAD ^ /dev/null)
    end
    popd

    if [ -n $git_branch_name ]
        set -l git_dirty_mark

        if set -q _pure_git_is_dirty
            set git_dirty_mark "*"
        end
        echo -n -s $git_branch_name $git_dirty_mark
    end
end


function _pure_update_git_last_pwd
    set -l working_tree $argv[1]
    if not set -q _pure_git_last_pwd
        set -g _pure_git_last_pwd $working_tree
        return 0
    end

    if [ $_pure_git_last_pwd = $working_tree ]
        return 0
    end

    # Reset git dirty state on directory change
    set -g _pure_git_last_pwd $working_tree
    set -e _pure_git_is_dirty
    set -e _pure_git_last_dirty_check_timestamp

    # Mask any failed staruses of set calls
    return 0
end

function fish_right_prompt
  set -l cyan (set_color cyan)
  set -l yellow (set_color yellow)
  set -l red (set_color red)
  set -l blue (set_color blue)
  set -l green (set_color green)
  set -l normal (set_color normal)
  set -l magenta (set_color magenta)
  set -l white (set_color white)
  set -l gray (set_color 666)

 
  # Print last command duration
  set -l cmd_duration (_pure_cmd_duration)

  if [ $cmd_duration ]
    echo -n -s $yellow " " $cmd_duration $normal
  end

  set -l git_working_tree (command git rev-parse --show-toplevel ^/dev/null)

  # Show git branch status
  if [ $git_working_tree ]
    _pure_update_git_last_pwd $git_working_tree
    set -l git_info (_pure_git_info $git_working_tree)
    if [ $git_info ]
      echo -n -s $gray " " $git_info $normal
    end

    set -l git_arrows (_pure_git_arrows $git_working_tree)
    if [ $git_arrows ]
      echo -n -s $cyan " " $git_arrows $normal
    end

    _pure_async_git_fetch $git_working_tree
    if set -q _pure_async_git_fetch_running
      echo -n -s $yellow " " (_pure_git_fetch_indicator) $normal
    end
  end
end
