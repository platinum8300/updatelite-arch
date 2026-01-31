#!/usr/bin/env bash
# phrases.sh - Motivational phrases module (with tech humor)

# Collection of phrases
PHRASES=(
    # Classic tech humor
    "There's no place like 127.0.0.1"
    "sudo make me a sandwich"
    "It works on my machine. Ship it."
    "Have you tried turning it off and on again?"
    "There's no place like ~"
    "chmod 777 your problems away (don't actually do this)"

    # Linux/Arch specific
    "BTW, I use Arch."
    "I use Arch btw. Oh wait, you already knew that."
    "AUR: where packages go to compile forever"
    "Arch: because life is too short for Ubuntu"
    "CachyOS: Arch for people who value their time"
    "pacman -Syu: the Russian roulette of rolling releases"
    "Another day without breaking the system. Impressive."
    "Your system is now 0.003% faster. You're welcome."

    # Programmer humor
    "99 little bugs in the code, 99 little bugs... patch one down, 127 bugs in the code"
    "Works on my machine. Certified."
    "git commit -m 'fixed it' (narrator: he didn't fix it)"
    "Documentation is like sex: when it's good, it's great. When it's bad, better than nothing."
    "// TODO: write better code (added 3 years ago)"
    "Technical debt is only debt if you plan to pay it back"

    # Existential tech
    "Somewhere, a server is crying"
    "Your legacy code misses you"
    "Orphan packages have found a new home: /dev/null"
    "Your dependencies are all in place. For now."
    "The kernel loves you. Probably."
    "systemd: because init was just too simple"

    # Motivational but make it tech
    "Keep calm and pacman -Syu"
    "May your builds be fast and your dependencies resolved"
    "May your compilations be short and your logs empty"
    "Live, laugh, rm -rf (carefully)"
    "Stay hungry, stay foolish, stay updated"
    "Move fast and don't break things (for once)"

    # Self-aware
    "This script has done more for you today than your ex"
    "Updates complete. Now go mass effect, no bullshit."
    "Your system is so clean it's almost suspicious"
    "Congrats, you've avoided dependency hell for another day"
    "All updated. Now you can procrastinate in peace."
    "System maintained. Mass effect time, enough bullshit."
    "Done. Now go touch grass or something."

    # References
    "I'm sorry Dave, I'm afraid I can't let you skip updates"
    "With great power comes great pacman -Syu"
    "In case of fire: git commit, git push, leave building"
    "There is no spoon, but there is paru"
    "One does not simply mass update production and expect a miracle (and yet, you hope)"

    # Dark humor
    "Your packages are updated. Your life... that's another story."
    "System clean, conscience... well, at least the system."
    "rm -rf doubt/"
    "The only bug I can't fix is you"
    "Kernel panic avoided. Existential crisis in progress."
)

# Get a random phrase
get_random_phrase() {
    local count=${#PHRASES[@]}
    local index=$((RANDOM % count))
    echo "${PHRASES[$index]}"
}

# Add custom phrase (for future use)
add_custom_phrase() {
    local phrase="$1"
    if [[ -n "$phrase" ]]; then
        PHRASES+=("$phrase")
    fi
}
