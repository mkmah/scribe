// Dropdown menu management for mention autocomplete

import { getCaretCoordinates } from "./cursor-manager.js"

let dropdown = null

/**
 * Get or create the dropdown element
 * @returns {HTMLElement} - Dropdown element
 */
function getOrCreateDropdown() {
    if (!dropdown) {
        dropdown = document.getElementById("mention-dropdown")
        if (!dropdown) {
            dropdown = document.createElement("div")
            dropdown.id = "mention-dropdown"
            dropdown.className = "mention-dropdown fixed w-56 bg-card border border-border rounded-lg shadow-lg z-[100] max-h-48 overflow-y-auto"
            document.body.appendChild(dropdown)
        }
    }
    return dropdown
}

/**
 * Show mention menu with filtered participants
 * @param {Array} participants - List of participants
 * @param {string} filter - Filter string
 * @param {HTMLElement} element - Contenteditable element
 * @param {Function} onSelect - Callback when participant is selected
 */
export function showMenu(participants, filter, element, onSelect) {
    const filterLower = (filter || "").toLowerCase()
    const filtered = participants.filter(p =>
        (p.name || "").toLowerCase().includes(filterLower)
    )

    if (filtered.length === 0) {
        hideMenu()
        return
    }

    const dropdownEl = getOrCreateDropdown()

    // Update dropdown content
    dropdownEl.innerHTML = `
      <div class="p-2 text-xs font-medium text-muted-foreground border-b border-border">
        Select Participant
      </div>
      ${filtered.map((p, index) => `
        <button
          type="button"
          class="mention-dropdown-item w-full text-left px-3 py-2 text-sm hover:bg-accent flex items-center gap-2 cursor-pointer"
          data-index="${index}"
          data-name="${p.name}"
          data-selected="${index === 0 ? 'true' : 'false'}"
        >
          <span class="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center text-xs font-medium text-primary">
            ${p.name.charAt(0)}
          </span>
          <span class="truncate">${p.name}</span>
        </button>
      `).join('')}
    `

    // Add click handlers to dropdown items
    dropdownEl.querySelectorAll(".mention-dropdown-item").forEach(item => {
        item.addEventListener("click", () => {
            const name = item.getAttribute("data-name")
            onSelect(name)
        })
    })

    dropdownEl.style.display = "block"
    positionDropdown(element, dropdownEl)
}

/**
 * Hide mention menu
 */
export function hideMenu() {
    const dropdownEl = document.getElementById("mention-dropdown")
    if (dropdownEl) {
        dropdownEl.style.display = "none"
    }
}

/**
 * Position dropdown relative to cursor
 * @param {HTMLElement} element - Contenteditable element
 * @param {HTMLElement} dropdownEl - Dropdown element
 */
export function positionDropdown(element, dropdownEl) {
    if (!dropdownEl) return

    // Defer positioning to ensure DOM has updated and selection range is ready
    // This is especially important when "@" is typed as the first character
    requestAnimationFrame(() => {
        const coords = getCaretCoordinates(element)
        const gap = 8
        const dropdownRect = dropdownEl.getBoundingClientRect()
        const dropdownHeight = Math.min(dropdownRect.height || 192, 192)
        const dropdownWidth = dropdownRect.width || 224
        const spaceBelow = window.innerHeight - coords.bottom
        const spaceAbove = coords.top

        // Viewport positioning: prefer below, flip above when not enough space
        if (spaceBelow < dropdownHeight + gap && spaceAbove > dropdownHeight + gap) {
            dropdownEl.style.top = "auto"
            dropdownEl.style.bottom = `${window.innerHeight - coords.top + gap}px`
        } else {
            dropdownEl.style.top = `${coords.bottom + gap}px`
            dropdownEl.style.bottom = "auto"
        }

        // Horizontal: align to caret, clamp to viewport
        let left = coords.left
        if (left + dropdownWidth > window.innerWidth - gap) left = window.innerWidth - dropdownWidth - gap
        if (left < gap) left = gap
        dropdownEl.style.left = `${left}px`
    })
}

/**
 * Update selected index in dropdown
 * @param {NodeList} items - Dropdown item elements
 * @param {number} selectedIndex - Currently selected index
 */
export function updateSelectedIndex(items, selectedIndex) {
    items.forEach((item, index) => {
        item.dataset.selected = index === selectedIndex ? "true" : "false"
    })

    // Scroll selected item into view
    const selected = items[selectedIndex]
    if (selected) {
        selected.scrollIntoView({ block: "nearest" })
    }
}

/**
 * Handle keyboard navigation in dropdown
 * @param {string} key - Key pressed
 * @param {NodeList} items - Dropdown item elements
 * @param {number} currentIndex - Current selected index
 * @param {Function} onSelect - Callback when participant is selected
 * @returns {{handled: boolean, newIndex?: number}} - Whether key was handled and new index
 */
export function handleKeyboardNavigation(key, items, currentIndex, onSelect) {
    switch (key) {
        case "ArrowDown":
            const nextIndex = Math.min(currentIndex + 1, items.length - 1)
            updateSelectedIndex(items, nextIndex)
            return { handled: true, newIndex: nextIndex }
        case "ArrowUp":
            const prevIndex = Math.max(currentIndex - 1, 0)
            updateSelectedIndex(items, prevIndex)
            return { handled: true, newIndex: prevIndex }
        case "Enter":
        case "Tab":
            const selectedItem = items[currentIndex]
            if (selectedItem) {
                const name = selectedItem.getAttribute("data-name")
                onSelect(name)
            }
            return { handled: true }
        case "Escape":
            hideMenu()
            return { handled: true }
        default:
            return { handled: false }
    }
}
