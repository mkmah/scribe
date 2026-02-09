import { getThemePref, applyTheme, updateIndicators, setTheme } from "./theme"

let Hooks = {}

// Simple theme toggle handler for icon button
Hooks.ThemeToggleHandler = {
    mounted() {
        this.el.addEventListener("toggle-theme", () => {
            const currentPref = getThemePref()
            let newPref

            // Toggle between light and dark
            if (currentPref === "dark") {
                newPref = "light"
            } else if (currentPref === "light") {
                newPref = "dark"
            } else {
                // If system, check current state and toggle
                const isDark = document.documentElement.classList.contains("dark")
                newPref = isDark ? "light" : "dark"
            }

            setTheme(newPref)
        })
    }
}

Hooks.ThemeToggle = {
    mounted() {
        const wrapper = this.el

        // Trigger button toggles the menu
        this._onTriggerClick = (e) => {
            e.stopPropagation()
            const menu = wrapper.querySelector("[data-theme-menu]")
            if (!menu) return
            const isVisible = menu.style.display === "block"
            menu.style.display = isVisible ? "none" : "block"
            if (!isVisible) updateIndicators(wrapper, getThemePref())
        }

        // Option buttons set the theme
        this._onOptionClick = (e) => {
            const btn = e.target.closest("[data-theme-option]")
            if (!btn) return
            const val = btn.getAttribute("data-theme-option")
            setTheme(val)
            const menu = wrapper.querySelector("[data-theme-menu]")
            if (menu) menu.style.display = "none"
            updateIndicators(wrapper, val)
        }

        // Close on outside click
        this._onDocClick = (e) => {
            if (!wrapper.contains(e.target)) {
                const menu = wrapper.querySelector("[data-theme-menu]")
                if (menu) menu.style.display = "none"
            }
        }

        // Use event delegation on the wrapper
        wrapper.addEventListener("click", (e) => {
            if (e.target.closest("[data-theme-trigger]")) {
                this._onTriggerClick(e)
            } else if (e.target.closest("[data-theme-option]")) {
                this._onOptionClick(e)
            }
        })

        document.addEventListener("click", this._onDocClick)
    },
    destroyed() {
        if (this._onDocClick) {
            document.removeEventListener("click", this._onDocClick)
        }
    }
}

Hooks.Clipboard = {
    mounted() {
        this.handleEvent("copy-to-clipboard", ({ text: text }) => {
            navigator.clipboard.writeText(text).then(() => {
                this.pushEventTo(this.el, "copied-to-clipboard", { text: text })
                setTimeout(() => {
                    this.pushEventTo(this.el, "reset-copied", {})
                }, 2000)
            })
        })
    }
}

Hooks.ScrollToBottom = {
    mounted() {
        this.scrollToBottom()
        this.observer = new MutationObserver(() => {
            this.scrollToBottom()
        })
        this.observer.observe(this.el, { childList: true, subtree: true })
    },
    updated() {
        this.scrollToBottom()
    },
    destroyed() {
        if (this.observer) {
            this.observer.disconnect()
        }
    },
    scrollToBottom() {
        this.el.scrollTop = this.el.scrollHeight
    }
}

// Auto-hide flash toast after duration (avoids JS.delay which is not in LiveView 1.0)
Hooks.FlashToast = {
    mounted() {
        console.log("FlashToast mounted:", this.el.id, this.el.textContent)
        // Always show toast when mounted (new element created)
        // Use requestAnimationFrame to ensure DOM is ready
        requestAnimationFrame(() => {
            this._showToast()
        })
    },
    updated() {
        console.log("FlashToast updated:", this.el.id, this.el.textContent)
        // When LiveView updates an existing element, always re-show it
        // This handles cases where the element might have been hidden
        requestAnimationFrame(() => {
            this._showToast()
        })
    },
    destroyed() {
        console.log("FlashToast destroyed:", this.el.id)
        if (this._timer) {
            clearTimeout(this._timer)
        }
    },
    _showToast() {
        // Clear any existing timer
        if (this._timer) {
            clearTimeout(this._timer)
        }
        
        // Ensure element is visible and reset any hidden state
        this.el.style.display = ""
        this.el.style.visibility = "visible"
        this.el.style.opacity = "1"
        
        // Force a reflow to ensure the element is visible before animation
        // This helps with CSS transitions
        void this.el.offsetHeight
        
        // Set up auto-hide timer
        const ms = parseInt(this.el.dataset.duration || "5000", 10)
        this._timer = setTimeout(() => {
            // Hide the toast after duration
            this.el.style.display = "none"
            // Remove the element from DOM after hiding animation completes
            setTimeout(() => {
                if (this.el && this.el.parentNode) {
                    this.el.remove()
                }
            }, 300) // Wait for fade-out animation
        }, ms)
    }
}

Hooks.TimezoneDetect = {
    mounted() {
        this._setTimezone()
    },
    updated() {
        this._setTimezone()
    },
    _setTimezone() {
        try {
            const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
            const el = this.el.querySelector("[data-detected-tz]")
            if (el) el.textContent = tz
        } catch (e) {
            // fallback
        }
    }
}

// Format datetime to browser's local timezone
Hooks.LocalDateTime = {
    mounted() {
        this._formatDateTime()
    },
    updated() {
        this._formatDateTime()
    },
    _formatDateTime() {
        const isoString = this.el.dataset.datetime
        if (!isoString) return

        try {
            const date = new Date(isoString)
            if (isNaN(date.getTime())) {
                // Invalid date, keep original text
                return
            }

            const format = this.el.dataset.format || 'datetime'
            this.el.textContent = this._format(date, format)
        } catch (e) {
            // If formatting fails, keep original ISO string
            console.error("Date formatting error:", e)
        }
    },
    _format(date, format) {
        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const yesterday = new Date(today)
        yesterday.setDate(yesterday.getDate() - 1)
        const dateOnly = new Date(date.getFullYear(), date.getMonth(), date.getDate())

        // Check if date is today or yesterday for relative formatting
        const isToday = dateOnly.getTime() === today.getTime()
        const isYesterday = dateOnly.getTime() === yesterday.getTime()

        switch (format) {
            case 'date':
                return this._formatDate(date)
            case 'time':
                return this._formatTime(date)
            case 'datetime':
                return this._formatDateAndTime(date)
            case 'relative':
                if (isToday) {
                    return `Today at ${this._formatTime(date)}`
                } else if (isYesterday) {
                    return `Yesterday at ${this._formatTime(date)}`
                } else {
                    return `${this._formatDate(date)} at ${this._formatTime(date)}`
                }
            case 'short':
                return this._formatShort(date)
            case 'medium':
                return this._formatMedium(date)
            case 'long':
                return this._formatLong(date)
            default:
                return this._formatDateAndTime(date)
        }
    },
    _formatDate(date) {
        return new Intl.DateTimeFormat(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }).format(date)
    },
    _formatTime(date) {
        return new Intl.DateTimeFormat(undefined, {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        }).format(date)
    },
    _formatDateAndTime(date) {
        return new Intl.DateTimeFormat(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        }).format(date)
    },
    _formatShort(date) {
        return new Intl.DateTimeFormat(undefined, {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }).format(date)
    },
    _formatMedium(date) {
        return new Intl.DateTimeFormat(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }).format(date)
    },
    _formatLong(date) {
        return new Intl.DateTimeFormat(undefined, {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        }).format(date)
    }
}

// Enhanced mention input with cursor positioning and pill rendering
Hooks.MentionInput = {
    mounted() {
        this.mentions = []
        this.phxTarget = this.el.getAttribute("phx-target")
        this.dropdown = null
        this.selectedIndex = 0
        this.isMenuVisible = false
        this.atSymbolIndex = -1
        this.isContentEditable = this.el.getAttribute("contenteditable") === "true"
        this.participants = []

        // Load participants from form data attribute (HTML-unescaped by the browser)
        const form = this.el.closest("form")
        if (form && form.dataset.participants) {
            try {
                this.participants = JSON.parse(form.dataset.participants)
            } catch (e) {
                console.error("Failed to parse participants data:", e)
            }
        }

        this._setupEventListeners()
        this._cleanupEmptyNodes()
    },

    _cleanupEmptyNodes() {
        // Remove empty text nodes to ensure :empty pseudo-class works
        // Only clean up when contenteditable is empty or nearly empty
        // Preserve user-typed spaces and line breaks (<br>)
        const textNodes = []
        const walker = document.createTreeWalker(
            this.el,
            NodeFilter.SHOW_TEXT,
            null
        )

        let node
        while (node = walker.nextNode()) {
            textNodes.push(node)
        }

        // Check if there's any real content (pills or non-whitespace text)
        const hasPills = this.el.querySelector(".mention-pill") !== null
        const hasNonWhitespaceText = textNodes.some(tn => tn.textContent.trim() !== "")

        // Only clean up if there's no real content
        if (!hasPills && !hasNonWhitespaceText) {
            // Remove all empty text nodes and <br> elements when truly empty
            textNodes.forEach(textNode => {
                if (textNode.textContent === "") {
                    textNode.remove()
                }
            })
            this.el.querySelectorAll('br').forEach(br => br.remove())
        } else {
            // When there's content, only remove truly empty nodes (not whitespace-only)
            textNodes.forEach(textNode => {
                if (textNode.textContent === "") {
                    textNode.remove()
                }
            })
            // Preserve <br> elements when there's content (they're line breaks)
        }
    },

    _ensureValidCursor() {
        // Ensure cursor is in a valid position after cleanup
        // If contenteditable is empty, place cursor at start
        // Otherwise, ensure cursor is in a valid text node or at end
        const selection = window.getSelection()
        if (!selection.rangeCount) {
            const newRange = document.createRange()
            newRange.selectNodeContents(this.el)
            newRange.collapse(true)
            selection.addRange(newRange)
            return
        }

        const currentRange = selection.getRangeAt(0)
        const startContainer = currentRange.startContainer

        // If cursor is in a removed node or invalid position, reposition it
        if (!this.el.contains(startContainer) || (startContainer.nodeType === Node.ELEMENT_NODE && startContainer.classList?.contains("mention-pill"))) {
            // Place cursor at end of content or start if empty
            const newRange = document.createRange()
            if (this.el.childNodes.length === 0) {
                newRange.setStart(this.el, 0)
                newRange.collapse(true)
            } else {
                const lastNode = this.el.lastChild
                if (lastNode.nodeType === Node.TEXT_NODE) {
                    newRange.setStart(lastNode, lastNode.length)
                } else {
                    newRange.setStartAfter(lastNode)
                }
                newRange.collapse(true)
            }
            selection.removeAllRanges()
            selection.addRange(newRange)
        }
    },

    _setupEventListeners() {
        if (this.isContentEditable) {
            // Contenteditable div handling
            this.el.addEventListener("input", (e) => {
                this._handleInput(e)
            })

            this.el.addEventListener("keydown", (e) => {
                this._handleKeydown(e)
            })

            this.el.addEventListener("click", () => {
                this._hideMentionMenu()
            })

            // Prevent paste from bringing in formatting
            this.el.addEventListener("paste", (e) => {
                e.preventDefault()
                const text = e.clipboardData.getData("text/plain")
                document.execCommand("insertText", false, text)
            })
        } else {
            // Fallback for textarea
            this.el.addEventListener("input", (e) => {
                const text = e.target.value
                const cursorPos = e.target.selectionStart

                // Find @ symbol before cursor
                const textBeforeCursor = text.substring(0, cursorPos)
                const atMatch = textBeforeCursor.match(/@(\w*)$/)

                if (atMatch) {
                    this.pushEventTo(this.phxTarget, "show_mention_menu", { filter: atMatch[1] })
                } else {
                    this.pushEventTo(this.phxTarget, "hide_mention_menu", {})
                }
            })
        }

        // Handle mention insertion from server
        this.handleEvent("insert_mention", ({ name }) => {
            if (this.isContentEditable) {
                this._insertMentionPill(name)
            } else {
                this._insertMentionPlainText(name)
            }
        })
    },

    _handleInput(e) {
        const text = this._getTextContent()
        const cursorPos = this._getCaretPosition()

        // Find @ symbol before cursor - trigger for @ alone (show all) or @ plus letters (filter)
        const textBeforeCursor = text.substring(0, cursorPos)
        const atMatch = textBeforeCursor.match(/@(\w*)$/)

        if (atMatch && !this._isCursorInMention()) {
            this.atSymbolIndex = cursorPos - atMatch[0].length
            this.currentFilter = atMatch[1]
            this.selectedIndex = 0
            this.isMenuVisible = true

            // Show menu using client-side filtering (no server round-trip)
            this._showMentionMenuClient(atMatch[1])
        } else {
            this._hideMentionMenu()
        }

        // Don't call cleanup on every input - it interferes with normal typing
        // Cleanup is only called when pills are removed or when explicitly needed
    },

    _getParticipants() {
        // Read current list from form (LiveView updates data-participants when chat opens)
        const form = this.el.closest("form")
        if (!form || !form.dataset.participants) return []
        try {
            return JSON.parse(form.dataset.participants)
        } catch (_) {
            return []
        }
    },

    _showMentionMenuClient(filter) {
        const participants = this._getParticipants()
        const filterLower = (filter || "").toLowerCase()
        const filtered = participants.filter(p =>
            (p.name || "").toLowerCase().includes(filterLower)
        )

        if (filtered.length === 0) {
            this._hideMentionMenu()
            return
        }

        // Create or update dropdown (append to body for correct fixed positioning)
        let dropdown = document.getElementById("mention-dropdown")
        if (!dropdown) {
            dropdown = document.createElement("div")
            dropdown.id = "mention-dropdown"
            dropdown.className = "mention-dropdown fixed w-56 bg-card border border-border rounded-lg shadow-lg z-[100] max-h-48 overflow-y-auto"
            document.body.appendChild(dropdown)
        }

        // Update dropdown content
        dropdown.innerHTML = `
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
        dropdown.querySelectorAll(".mention-dropdown-item").forEach(item => {
          item.addEventListener("click", () => {
            const name = item.getAttribute("data-name")
            this._insertMentionPill(name)
          })
        })

        dropdown.style.display = "block"
        this._positionDropdown()
    },

    _handleKeydown(e) {
        // When mention menu is visible, handle navigation keys
        if (this.isMenuVisible) {
            // Prevent form submission with Enter when menu is visible
            if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault()
                e.stopPropagation()
            }

            const dropdown = document.getElementById("mention-dropdown")
            if (!dropdown) return

            const items = dropdown.querySelectorAll(".mention-dropdown-item")

            switch (e.key) {
                case "ArrowDown":
                    e.preventDefault()
                    this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
                    this._updateSelectedIndex(items)
                    return
                case "ArrowUp":
                    e.preventDefault()
                    this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
                    this._updateSelectedIndex(items)
                    return
                case "Enter":
                case "Tab":
                    e.preventDefault()
                    const selectedItem = items[this.selectedIndex]
                    if (selectedItem) {
                        const name = selectedItem.getAttribute("data-name")
                        this._insertMentionPill(name)
                    }
                    return
                case "Escape":
                    e.preventDefault()
                    this._hideMentionMenu()
                    return
            }
            return
        }

        // Handle Shift+Enter for new lines
        if (e.key === "Enter" && e.shiftKey) {
            // Insert <br> for line break in contenteditable
            e.preventDefault()
            const selection = window.getSelection()
            if (selection.rangeCount) {
                const range = selection.getRangeAt(0)
                const br = document.createElement("br")
                range.deleteContents()
                range.insertNode(br)
                // Move cursor after the <br>
                range.setStartAfter(br)
                range.collapse(true)
                selection.removeAllRanges()
                selection.addRange(range)
            }
            return
        }

        // When menu is not visible, handle backspace to delete mention pills
        if (e.key === "Backspace") {
            this._handleBackspace(e)
        }
    },

    _insertMentionPill(name) {
        const cursorPos = this._getCaretPosition()
        let startIndex = this.atSymbolIndex
        if (startIndex === -1) startIndex = cursorPos

        const pill = this._createPillElement(name)
        const range = document.createRange()

        if (startIndex === cursorPos) {
            // From "Add context": insert at cursor (collapsed range)
            const start = this._getNodeAndOffsetAtPosition(startIndex)
            if (!start) return
            range.setStart(start.node, start.offset)
            range.collapse(true)
        } else {
            // From @ trigger: replace from @ to caret
            const start = this._getNodeAndOffsetAtPosition(startIndex)
            const end = this._getNodeAndOffsetAtPosition(cursorPos)
            if (!start || !end) return
            range.setStart(start.node, start.offset)
            range.setEnd(end.node, end.offset)
        }

        range.deleteContents()
        range.insertNode(pill)
        range.setStartAfter(pill)
        range.collapse(true)
        range.insertNode(document.createTextNode(" "))
        range.setStartAfter(pill.nextSibling)
        range.collapse(true)

        const sel = window.getSelection()
        sel.removeAllRanges()
        sel.addRange(range)

        this.mentions.push({ name, index: this.mentions.length })
        this.el.dataset.mentions = this.mentions.map(m => m.name).join(",")
        this._hideMentionMenu()
        this.el.focus()
    },

    _getNodeAndOffsetAtPosition(pos) {
        let charCount = 0
        let result = null
        const traverse = (node) => {
            if (result) return
            if (node.nodeType === Node.TEXT_NODE) {
                const nextCount = charCount + node.length
                if (pos <= nextCount) {
                    result = { node, offset: pos - charCount }
                }
                charCount = nextCount
            } else if (node.classList && node.classList.contains("mention-pill")) {
                const len = 1 + (node.dataset.mention || "").length
                const nextCount = charCount + len
                if (pos <= nextCount) {
                    const parent = node.parentNode
                    const index = Array.from(parent.childNodes).indexOf(node)
                    result = { node: parent, offset: pos <= charCount ? index : index + 1 }
                }
                charCount = nextCount
            } else {
                for (const child of node.childNodes) {
                    traverse(child)
                    if (result) return
                }
            }
        }
        traverse(this.el)
        if (!result) {
            const last = this.el.lastChild
            if (last) {
                if (last.nodeType === Node.TEXT_NODE) result = { node: last, offset: last.length }
                else result = { node: this.el, offset: this.el.childNodes.length }
            } else {
                result = { node: this.el, offset: 0 }
            }
        }
        return result
    },

    _createPillElement(name) {
        const wrapper = document.createElement("span")
        wrapper.className = "mention-pill"
        wrapper.contentEditable = "false"
        wrapper.dataset.mention = name

        const avatar = document.createElement("span")
        avatar.className = "mention-pill-avatar"
        avatar.textContent = name.charAt(0).toUpperCase()

        const nameSpan = document.createElement("span")
        nameSpan.textContent = name

        wrapper.appendChild(avatar)
        wrapper.appendChild(nameSpan)

        return wrapper
    },

    _insertMentionPlainText(name) {
        // Fallback for textarea mode
        const text = this.el.value
        const cursorPos = this.el.selectionStart
        const textBeforeCursor = text.substring(0, cursorPos)
        const atIndex = textBeforeCursor.lastIndexOf("@")

        let newValue, newPos

        if (atIndex !== -1 && cursorPos - atIndex <= 20) {
            const before = text.substring(0, atIndex)
            const after = text.substring(cursorPos)
            newValue = before + "@" + name + " " + after
            newPos = atIndex + name.length + 2
        } else {
            const before = text.substring(0, cursorPos)
            const after = text.substring(cursorPos)
            newValue = before + "@" + name + " " + after
            newPos = cursorPos + name.length + 2
        }

        this.el.value = newValue
        this.el.setSelectionRange(newPos, newPos)
        this.el.focus()
    },

    _getPositionAfterNode(node) {
        if (!node.parentNode) return null
        const parent = node.parentNode
        const next = node.nextSibling
        if (next) return { node: next, offset: 0 }
        const idx = Array.from(parent.childNodes).indexOf(node)
        return { node: parent, offset: idx + 1 }
    },

    _getPositionBeforeNode(node) {
        if (!node.parentNode) return null
        const parent = node.parentNode
        const prev = node.previousSibling
        if (prev) {
            if (prev.nodeType === Node.TEXT_NODE) return { node: prev, offset: prev.length }
            return { node: parent, offset: Array.from(parent.childNodes).indexOf(node) }
        }
        return { node: parent, offset: Array.from(parent.childNodes).indexOf(node) }
    },

    _cursorIsAfterNode(node) {
        const selection = window.getSelection()
        if (!selection.rangeCount) return false
        const range = selection.getRangeAt(0)
        if (!range.collapsed) return false
        const after = this._getPositionAfterNode(node)
        if (!after) return false
        return range.startContainer === after.node && range.startOffset === after.offset
    },

    _cursorIsBeforeNode(node) {
        const selection = window.getSelection()
        if (!selection.rangeCount) return false
        const range = selection.getRangeAt(0)
        if (!range.collapsed) return false
        const before = this._getPositionBeforeNode(node)
        if (!before) return false
        return range.startContainer === before.node && range.startOffset === before.offset
    },

    _handleBackspace(e) {
        const selection = window.getSelection()
        if (!selection.rangeCount) return
        const range = selection.getRangeAt(0)
        if (!this.el.contains(range.startContainer)) return

        const pills = this.el.querySelectorAll(".mention-pill")
        for (const pill of pills) {
            if (this._cursorIsAfterNode(pill) || this._cursorIsBeforeNode(pill)) {
                e.preventDefault()
                const name = pill.dataset.mention
                // Remove trailing space if it exists (inserted with pill)
                const nextSibling = pill.nextSibling
                if (nextSibling && nextSibling.nodeType === Node.TEXT_NODE && nextSibling.textContent.trim() === "") {
                    nextSibling.remove()
                }
                pill.remove()
                this.mentions = this.mentions.filter(m => m.name !== name)
                this.el.dataset.mentions = this.mentions.map(m => m.name).join(",")
                this._cleanupEmptyNodes()
                this._ensureValidCursor()
                return
            }
        }

        const nodeBefore = this._getNodeImmediatelyBeforeCursor()
        if (nodeBefore?.classList?.contains("mention-pill")) {
            e.preventDefault()
            const name = nodeBefore.dataset.mention
            // Remove trailing space if it exists (inserted with pill)
            const nextSibling = nodeBefore.nextSibling
            if (nextSibling && nextSibling.nodeType === Node.TEXT_NODE && nextSibling.textContent.trim() === "") {
                nextSibling.remove()
            }
            nodeBefore.remove()
            this.mentions = this.mentions.filter(m => m.name !== name)
            this.el.dataset.mentions = this.mentions.map(m => m.name).join(",")
            this._cleanupEmptyNodes()
            this._ensureValidCursor()
        }
    },

    _getNodeImmediatelyBeforeCursor() {
        const selection = window.getSelection()
        if (!selection.rangeCount) return null
        const range = selection.getRangeAt(0)
        if (!range.collapsed || !this.el.contains(range.startContainer)) return null

        const sc = range.startContainer
        const so = range.startOffset

        if (sc.nodeType === Node.TEXT_NODE) {
            if (so === 0) {
                let prev = sc.previousSibling
                while (prev && prev.nodeType === Node.TEXT_NODE && prev.textContent.trim() === "") prev = prev.previousSibling
                if (prev?.classList?.contains("mention-pill")) return prev
                if (prev?.nodeType === Node.ELEMENT_NODE) return prev.querySelector(".mention-pill") || null
                return null
            }
            // Handle case where cursor is inside text node with offset > 0
            // If the text before cursor is only whitespace, check if previous sibling is a pill
            const textBeforeCursor = sc.textContent.slice(0, so)
            if (/^\s*$/.test(textBeforeCursor)) {
                let prev = sc.previousSibling
                while (prev && prev.nodeType === Node.TEXT_NODE && prev.textContent.trim() === "") prev = prev.previousSibling
                if (prev?.classList?.contains("mention-pill")) return prev
            }
            return null
        }

        if (sc.nodeType === Node.ELEMENT_NODE && so > 0) {
            const prev = sc.childNodes[so - 1]
            if (prev?.classList?.contains("mention-pill")) return prev
            if (prev?.nodeType === Node.ELEMENT_NODE) {
                const last = prev.querySelector(".mention-pill")
                if (last) return last
                const walk = (n) => {
                    if (!n.childNodes.length) return n
                    const l = n.childNodes[n.childNodes.length - 1]
                    return l.nodeType === Node.ELEMENT_NODE ? walk(l) : l.previousSibling || l
                }
                const deep = walk(prev)
                return deep?.classList?.contains("mention-pill") ? deep : prev.querySelector(".mention-pill")
            }
        }
        return null
    },

    _waitForDropdownThenPosition() {
        // Wait for next tick for dropdown to appear
        setTimeout(() => {
            this._positionDropdown()
        }, 10)
    },

    _positionDropdown() {
        const dropdown = document.getElementById("mention-dropdown")
        if (!dropdown) return

        const coords = this._getCaretCoordinates()
        const gap = 8
        const dropdownRect = dropdown.getBoundingClientRect()
        const dropdownHeight = Math.min(dropdownRect.height || 192, 192)
        const dropdownWidth = dropdownRect.width || 224
        const spaceBelow = window.innerHeight - coords.bottom
        const spaceAbove = coords.top

        // Viewport positioning: prefer below, flip above when not enough space
        if (spaceBelow < dropdownHeight + gap && spaceAbove > dropdownHeight + gap) {
            dropdown.style.top = "auto"
            dropdown.style.bottom = `${window.innerHeight - coords.top + gap}px`
        } else {
            dropdown.style.top = `${coords.bottom + gap}px`
            dropdown.style.bottom = "auto"
        }

        // Horizontal: align to caret, clamp to viewport
        let left = coords.left
        if (left + dropdownWidth > window.innerWidth - gap) left = window.innerWidth - dropdownWidth - gap
        if (left < gap) left = gap
        dropdown.style.left = `${left}px`
    },

    _updateSelectedIndex(items) {
        items.forEach((item, index) => {
            item.dataset.selected = index === this.selectedIndex ? "true" : "false"
        })

        // Scroll selected item into view
        const selected = items[this.selectedIndex]
        if (selected) {
            selected.scrollIntoView({ block: "nearest" })
        }
    },

    _hideMentionMenu() {
        this.isMenuVisible = false
        this.selectedIndex = 0
        this.atSymbolIndex = -1

        // Hide client-side dropdown
        const dropdown = document.getElementById("mention-dropdown")
        if (dropdown) {
            dropdown.style.display = "none"
        }

        // Also notify server for consistency
        this.pushEventTo(this.phxTarget, "hide_mention_menu", {})
    },

    _getCaretPosition() {
        const selection = window.getSelection()
        if (!selection.rangeCount) return 0

        const range = selection.getRangeAt(0)
        const preCaretRange = range.cloneRange()
        preCaretRange.selectNodeContents(this.el)
        preCaretRange.setEnd(range.endContainer, range.endOffset)
        return preCaretRange.toString().length
    },

    _setCaretPosition(pos) {
        const range = document.createRange()
        const selection = window.getSelection()

        let charCount = 0
        let found = false

        const traverse = (node) => {
            if (found) return

            if (node.nodeType === Node.TEXT_NODE) {
                const nextCount = charCount + node.length
                if (pos <= nextCount) {
                    range.setStart(node, pos - charCount)
                    range.collapse(true)
                    found = true
                }
                charCount = nextCount
            } else {
                for (const child of node.childNodes) {
                    traverse(child)
                    if (found) return
                }
            }
        }

        traverse(this.el)

        if (!found) {
            range.selectNodeContents(this.el)
            range.collapse(false)
        }

        selection.removeAllRanges()
        selection.addRange(range)
    },

    _getCaretCoordinates() {
        const selection = window.getSelection()
        if (!selection.rangeCount) return { left: 0, top: 0, bottom: 0 }

        const range = selection.getRangeAt(0)
        const rects = range.getClientRects()

        if (rects.length > 0) {
            const rect = rects[0]
            return { left: rect.left, top: rect.top, bottom: rect.bottom }
        }

        // Fallback: use first rect
        const rect = range.getBoundingClientRect()
        return { left: rect.left, top: rect.top, bottom: rect.bottom }
    },

    _getTextContent() {
        // Get plain text from contenteditable (including nested divs/p), replacing pills with @name
        const traverse = (node) => {
            if (node.nodeType === Node.TEXT_NODE) return node.textContent
            if (node.classList?.contains("mention-pill")) return "@" + (node.dataset.mention || "")
            let s = ""
            for (const child of node.childNodes) s += traverse(child)
            return s
        }
        return traverse(this.el)
    },

    _isCursorInMention() {
        const selection = window.getSelection()
        if (!selection.rangeCount) return false

        const range = selection.getRangeAt(0)
        let node = range.startContainer

        // Check if cursor is within or after a mention pill
        while (node && node !== this.el) {
            if (node.classList?.contains("mention-pill")) {
                return true
            }
            node = node.parentNode
        }
        return false
    }
}

// Sync mention content to hidden input on form submit
Hooks.MentionSync = {
    mounted() {
        const form = this.el.closest("form")
        if (!form) return

        this._syncContent = () => {
            const textarea = document.getElementById("chat-popup-textarea")
            if (!textarea) return

            // Extract text with @mentions
            let text = ""
            for (const child of textarea.childNodes) {
                if (child.classList?.contains("mention-pill")) {
                    text += "@" + child.dataset.mention
                } else if (child.nodeType === Node.TEXT_NODE) {
                    text += child.textContent
                }
            }

            this.el.value = text.trim()
        }

        // Sync on form submit
        form.addEventListener("submit", (e) => {
            this._syncContent()
        })

        // Also sync on input to keep hidden input updated
        const textarea = document.getElementById("chat-popup-textarea")
        if (textarea) {
            textarea.addEventListener("input", () => {
                this._syncContent()
            })
        }
    }
}

export default Hooks
