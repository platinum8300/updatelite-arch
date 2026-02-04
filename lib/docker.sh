#!/usr/bin/env bash
# docker.sh - Docker update module (matches original visual style)
#
# Copyright (C) 2026 platinum8300
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Update Docker containers with Watchtower
update_docker() {
    if [[ "$ENABLE_DOCKER" != "true" ]]; then
        return 0
    fi

    if ! has_command docker; then
        return 0
    fi

    show_section "DOCKER - Containers" "${BLUE}" "🐋"

    # Check if there are running containers
    local running_containers
    running_containers=$(docker ps -q 2>/dev/null | wc -l)

    if [[ $running_containers -eq 0 ]]; then
        echo -e "${YELLOW}  ℹ️  No active containers${RESET}"
        end_section
        return 0
    fi

    echo -e "${BLUE}  → Updating ${running_containers} container(s) with Watchtower...${RESET}"
    echo ""

    local docker_exit
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once
    docker_exit=$?

    echo ""
    if [[ $docker_exit -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Containers updated${RESET}"
        UPDATES_DOCKER=$running_containers
    else
        echo -e "${YELLOW}  ⚠️  Some containers were not updated${RESET}"
    fi

    end_section
}
