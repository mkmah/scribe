import { getThemePref, updateIndicators, setTheme } from "./theme"
import { extractTextWithMentions, cleanupEmptyNodes, updatePlaceholderVisibility, isTrulyEmpty } from "./mention/dom-utils.js"
import { insertPillAtEnd, insertPillAtCursor, rebuildMentionsFromDOM } from "./mention/pill-manager.js"
import { showMenu, hideMenu } from "./mention/menu-manager.js"
import { restoreContent, setupMutationObserver } from "./mention/content-restorer.js"
import { handleInput as handleInputEvent } from "./mention/input-handler.js"
import { loadParticipants, getParticipants, clearInput, setupFormListeners, syncContentToHiddenInput, handleFormSubmit } from "./mention/form-handler.js"
import { handleKeydown } from "./mention/keydown-handler.js"

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
        // Format as "November 13, 2025" (month name, day number, comma, year)
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                           'July', 'August', 'September', 'October', 'November', 'December']
        const month = monthNames[date.getMonth()]
        const day = date.getDate()
        const year = date.getFullYear()
        return `${month} ${day}, ${year}`
    },
    _formatTime(date) {
        // Format time as HH:MMam/pm (lowercase, no space)
        const hour = date.getHours()
        const minute = date.getMinutes()
        const ampm = hour >= 12 ? 'pm' : 'am'
        const hour12 = hour % 12 || 12
        const minuteStr = minute.toString().padStart(2, '0')
        return `${hour12}:${minuteStr}${ampm}`
    },
    _formatDateAndTime(date) {
        // Format as "11:17am - November 13, 2025"
        const time = this._formatTime(date)
        const dateStr = this._formatDate(date)
        return `${time} - ${dateStr}`
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
        // Format as "November 3, 2025" (same as date format)
        return this._formatDate(date)
    }
}

// Enhanced mention input with cursor positioning and pill rendering
Hooks.MentionInput = {
    mounted() {
        this.phxTarget = this.el.getAttribute("phx-target")
        this.isContentEditable = this.el.getAttribute("contenteditable") === "true"
        
        // Consolidated state management
        this.state = {
            mentions: [],
            selectedIndex: 0,
            isMenuVisible: false,
            atSymbolIndex: -1,
            storedContent: null,
            isInserting: false
        }

        // Load participants from form data attribute
        this.state.participants = loadParticipants(this.el)

        // Helper to get text content
        this._getTextContent = () => extractTextWithMentions(this.el)

        this._setupEventListeners()
        
        // Setup mutation observer (simplified - phx-update="ignore" means LiveView won't touch this)
        this._observer = setupMutationObserver(this.el, {
            onRestore: () => {
                this.state.mentions = rebuildMentionsFromDOM(this.el)
            }
        })
        
        cleanupEmptyNodes(this.el)
        updatePlaceholderVisibility(this.el)
    },

    updated() {
        // With phx-update="ignore", LiveView shouldn't touch this element
        // Just update placeholder visibility
        updatePlaceholderVisibility(this.el)
        
        // If content is empty and we're not inserting, clear stored content
        if (isTrulyEmpty(this.el) && !this.state.isInserting) {
            this.state.storedContent = null
        }
    },

    destroyed() {
        if (this._observer) {
            this._observer.disconnect()
        }
    },

    _setupEventListeners() {
        if (this.isContentEditable) {
            // Contenteditable div handling
            this.el.addEventListener("input", (e) => {
                handleInputEvent(this.el, e, this._getTextContent, {
                    onMentionTrigger: (filter, index) => {
                        this.state.atSymbolIndex = index
                        this.state.selectedIndex = 0
                        this.state.isMenuVisible = true
                        showMenu(getParticipants(this.el), filter, this.el, (name) => {
                            this._insertMentionPill(name)
                        })
                    },
                    onMentionHide: () => {
                        hideMenu()
                        this.state.isMenuVisible = false
                    }
                }, this.state)
            })

            this.el.addEventListener("keydown", (e) => {
                handleKeydown(e, this.el, this.state, this._getTextContent, (name) => {
                    this._insertMentionPill(name)
                }, () => {
                    this._submitForm()
                })
            })

            this.el.addEventListener("click", () => {
                hideMenu()
                this.state.isMenuVisible = false
            })

            // Prevent paste from bringing in formatting
            this.el.addEventListener("paste", (e) => {
                e.preventDefault()
                const text = e.clipboardData.getData("text/plain")
                document.execCommand("insertText", false, text)
            })

            // Setup form listeners for content storage and submission
            setupFormListeners(this.el, this._getTextContent, this.state, (clearHidden) => {
                clearInput(this.el, this.state, clearHidden)
            })
        } else {
            // Fallback for textarea
            this.el.addEventListener("input", (e) => {
                const text = e.target.value
                const cursorPos = e.target.selectionStart
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
                // Simplified: if we have stored content, restore it first, then append mention at end
                if (this.state.storedContent) {
                    restoreContent(this.el, this.state.storedContent)
                    this.state.mentions = rebuildMentionsFromDOM(this.el)
                    
                    // Insert mention at end
                    requestAnimationFrame(() => {
                        this.state.mentions = insertPillAtEnd(this.el, name)
                        hideMenu()
                        this.state.isMenuVisible = false
                        this.state.storedContent = null
                        this.state.isInserting = false
                    })
                } else {
                    // Insert at current cursor position
                    this.state.mentions = insertPillAtCursor(this.el, name, this.state.atSymbolIndex)
                    hideMenu()
                    this.state.isMenuVisible = false
                }
            } else {
                this._insertMentionPlainText(name)
            }
        })
    },

    _submitForm() {
        const hiddenInput = document.getElementById("chat-popup-message-input")
        const form = this.el.closest("form")
        
        if (!hiddenInput || !form) return
        
        // Sync content to hidden input
        syncContentToHiddenInput(this.el, hiddenInput)
        
        // Submit form if not already submitting
        if (!form.hasAttribute("data-submitting")) {
            form.setAttribute("data-submitting", "true")
            form.requestSubmit()
            
            // Clear input after submission
            clearInput(this.el, this.state, true)
            
            setTimeout(() => {
                form.removeAttribute("data-submitting")
            }, 1000)
        }
    },


    _insertMentionPill(name) {
        this.state.mentions = insertPillAtCursor(this.el, name, this.state.atSymbolIndex)
        hideMenu()
        this.state.isMenuVisible = false
        this.state.atSymbolIndex = -1
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
    }
}

// Sync mention content to hidden input on form submit
Hooks.MentionSync = {
    mounted() {
        const form = this.el.closest("form")
        if (!form) return

        const textarea = document.getElementById("chat-popup-textarea")
        if (!textarea) return

        // Sync on form submit
        form.addEventListener("submit", (e) => {
            if (!handleFormSubmit(this.el, textarea, form)) {
                e.preventDefault()
            }
        })

        // Also sync on input to keep hidden input updated
        textarea.addEventListener("input", () => {
            syncContentToHiddenInput(textarea, this.el)
        })
    }
}

export default Hooks
