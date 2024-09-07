#!/bin/bash

# Function to display all SSH connections in a formatted table
display_ssh_sessions() {
    echo "SSH Sessions Overview:"
    echo "--------------------------------------------"
    echo "| User              | Connections           |"
    echo "--------------------------------------------"
    ps lax | grep sshd | awk '{print $NF}' | sort | uniq -c | sort -nr | grep -v priv | sed 's/^ *//' | \
    while read -r count user; do
        if id -u "$user" >/dev/null 2>&1 && [ "$(id -u "$user")" -ge 1000 ]; then
            printf "| %-18s| %-21s|\n" "$user" "$count"
        fi
    done
    echo "--------------------------------------------"
    
    echo
    echo "Users with multiple connections:"
    echo "--------------------------------------------"
    ps lax | grep sshd | awk '{print $NF}' | sort | uniq -c | sort -nr | grep -v priv | \
    while read -r count user; do
        if [ "$count" -gt 1 ] && id -u "$user" >/dev/null 2>&1 && [ "$(id -u "$user")" -ge 1000 ]; then
            printf "| %-18s| %-21s|\n" "$user" "$count"
        fi
    done
    echo "--------------------------------------------"
}

# Function to display non-system users and allow selection by number
select_user() {
	users=($(awk -F: '$3 >= 1000 && $3 <= 60000 { print $1 }' /etc/passwd | sort))
    echo "Available users:"
    for i in "${!users[@]}"; do
        echo "$i) ${users[$i]}"
    done
    
    read -p "Select a user by number: " user_choice
    if [[ "$user_choice" -ge 0 && "$user_choice" -lt "${#users[@]}" ]]; then
        selected_user="${users[$user_choice]}"
        echo "You selected: $selected_user"
    else
        echo "Invalid selection. Please try again."
        selected_user=""
    fi
}

# Function to kill a user session by selection
kill_user_session() {
    select_user
    if [ -n "$selected_user" ]; then
        user_pid=$(ps lax | grep "$selected_user" | grep -v grep | awk '{print $3}')
        if [ -z "$user_pid" ]; then
            echo "No active session found for user: $selected_user"
        else
            echo "Killing session for user: $selected_user (PID: $user_pid)"
            sudo kill -9 $user_pid
            echo "Session killed."
        fi
    fi
}

# Function to lock/unlock users with user selection by number
lock_unlock_user() {
    list_locked_vpn_users
    select_user
    if [ -n "$selected_user" ]; then
        read -p "(L) Lock / (U) Unlock? " action
        case "$action" in
            L|l)
                if sudo passwd -S "$selected_user" | grep ' L ' >/dev/null; then
                    echo "User '$selected_user' is already locked."
                else
                    echo "Locking user: $selected_user"
                    user_pid=$(ps lax | grep "$selected_user" | grep -v grep | awk '{print $3}')
                    sudo usermod -L "$selected_user"
                    sudo kill -9 $user_pid
                    echo "User '$selected_user' has been locked."
                fi
                ;;
            U|u)
                if sudo passwd -S "$selected_user" | grep ' L ' >/dev/null; then
                    echo "Unlocking user: $selected_user"
                    sudo usermod -U "$selected_user"
                    echo "User '$selected_user' has been unlocked."
                else
                    echo "User '$selected_user' is not locked."
                fi
                ;;
            *)
                echo "Invalid action. Please enter 'L' to lock or 'U' to unlock."
                ;;
        esac
    fi
}

# Function to list locked VPN users in a pretty table
list_locked_vpn_users() {
    echo "--------------------------------------------"
    echo "| Locked VPN Users                          |"
    echo "--------------------------------------------"
    sudo passwd -S -a | grep ' L ' | awk '{print $1}' | sort | while read -r user; do
        if id -u "$user" >/dev/null 2>&1 && [ "$(id -u "$user")" -ge 1000 ]; then
            printf "| %-40s|\n" "$user"
        fi
    done
    echo "--------------------------------------------"
}

# Function to add a user with a default shell
add_user() {
    read -p "Enter username to add: " new_user
    if id "$new_user" &>/dev/null; then
        echo "User '$new_user' already exists."
    else
        sudo useradd -m -s /usr/bin/false "$new_user"
        echo "User '$new_user' added with /usr/bin/false as the default shell."
    fi
}

# Function to remove a user
remove_user() {
    select_user
    if [ -n "$selected_user" ]; then
        sudo userdel -r "$selected_user"
        echo "User '$selected_user' has been removed."
    fi
}

# Main script menu
clear
display_ssh_sessions  # Show connections when the script starts

while true; do
    echo
    echo "Choose an action:"
    echo "1) Refresh and display SSH sessions"
    echo "2) Kill user session"
    echo "3) Lock/Unlock a user"
    echo "4) View locked VPN users"
    echo "5) Add a new user"
    echo "6) Remove a user"
    echo "7) Exit"

    
    read -p "Enter your choice: " choice
    
    case "$choice" in
        1)
            clear
            display_ssh_sessions
            ;;
        2)
            kill_user_session
            ;;
        3)
            lock_unlock_user
            ;;
        4)
            list_locked_vpn_users
            ;;
        5)
            add_user
            ;;
        6)
            remove_user
            ;;
        7)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid choice. Please enter a number between 1 and 5."
            ;;
    esac
done

