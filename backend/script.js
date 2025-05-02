let selectedUsername = null;
let userMessageCount = {}; // Store message count for each user

// Load user list
async function loadUsers() {
    try {
        const response = await fetch('http://127.0.0.1:3000/users');
        const users = await response.json();
        const userList = document.getElementById('userList');
        userList.innerHTML = '';

        users.forEach(user => {
            const userDiv = document.createElement('div');
            userDiv.className = 'p-2 border rounded-md cursor-pointer hover:bg-green-100 flex items-center';
            userDiv.innerHTML = `
                <span>${user.username}</span>
                <span class="red-dot" id="redDot-${user.username}"></span>
            `;
            userDiv.onclick = () => selectUser(user.username);
            userList.appendChild(userDiv);

            // Initialize message count
            if (!userMessageCount[user.username]) {
                userMessageCount[user.username] = 0;
            }
        });
    } catch (error) {
        console.error('❌ Failed to load user list:', error);
    }
}

// Select user and load chat history and suggestions
async function selectUser(username) {
    selectedUsername = username;
    document.getElementById('selectedUser').textContent = `Chatting with: ${username}`;
    document.getElementById('chatBox').innerHTML = '';
    document.getElementById('suggestionBox').innerHTML = '';

    // Clear red dot
    const redDot = document.getElementById(`redDot-${username}`);
    if (redDot) {
        redDot.style.display = 'none';
    }

    await loadChatHistory(username);
    await loadSuggestions(username);
}

// Load chat history
async function loadChatHistory(username, isAutoRefresh = false) {
    try {
        const response = await fetch(`http://127.0.0.1:3000/getChatHistory/${username}`);
        const data = await response.json();
        const chatBox = document.getElementById('chatBox');

        const previousMessageCount = userMessageCount[username] || 0;
        const newMessageCount = data.chatHistory ? data.chatHistory.length : 0;

        // Check for new messages
        if (isAutoRefresh && newMessageCount > previousMessageCount) {
            const userDiv = Array.from(document.getElementById('userList').children).find(
                div => div.querySelector('span').textContent === username
            );
            if (userDiv) {
                // Show red dot
                const redDot = document.getElementById(`redDot-${username}`);
                if (redDot) {
                    redDot.style.display = 'inline-block';
                }
                // Move to top
                document.getElementById('userList').prepend(userDiv);
            }
        }

        userMessageCount[username] = newMessageCount;

        // If not the currently selected user, only update count, don't refresh UI
        if (username !== selectedUsername) {
            return;
        }

        chatBox.innerHTML = '';
        if (data.chatHistory && data.chatHistory.length > 0) {
            data.chatHistory.forEach(chat => {
                const messageDiv = document.createElement('div');
                messageDiv.className = chat.category === 'worker' ? 'message-worker' : 'message-user';
                messageDiv.textContent = `${chat.message} (${new Date(chat.timestamp).toLocaleString()})`;
                chatBox.appendChild(messageDiv);
            });

            // Scroll to latest message
            chatBox.scrollTop = chatBox.scrollHeight;
        }
    } catch (error) {
        console.error('❌ Failed to load chat history:', error);
    }
}

// Send message
async function sendMessage() {
    if (!selectedUsername) {
        alert('Please select a user first!');
        return;
    }

    const messageInput = document.getElementById('messageInput');
    const message = messageInput.value.trim();
    if (!message) {
        alert('Message cannot be empty!');
        return;
    }

    try {
        const response = await fetch('http://127.0.0.1:3000/sendMessage', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ username: selectedUsername, message }),
        });

        const result = await response.json();
        if (response.ok) {
            // Clear input
            messageInput.value = '';
            // Refresh chat history
            await loadChatHistory(selectedUsername);
        } else {
            alert(result.message || '❌ Failed to send message');
        }
    } catch (error) {
        console.error('❌ Failed to send message:', error);
        alert('❌ Failed to send message');
    }
}

// Search users
function searchUsers() {
    const searchInput = document.getElementById('searchUser').value.toLowerCase();
    const userDivs = document.getElementById('userList').getElementsByTagName('div');

    for (let userDiv of userDivs) {
        const username = userDiv.querySelector('span').textContent.toLowerCase();
        userDiv.style.display = username.includes(searchInput) ? 'flex' : 'none';
    }
}

// Load suggestions
async function loadSuggestions(username) {
    try {
        const response = await fetch(`http://127.0.0.1:3000/api/sugg/${username}`);
        const data = await response.json();
        const suggestionBox = document.getElementById('suggestionBox');
        suggestionBox.innerHTML = '';

        if (data.suggestions && data.suggestions.length > 0) {
            data.suggestions.forEach(sugg => {
                const suggDiv = document.createElement('div');
                suggDiv.className = 'p-2 border-b';
                suggDiv.textContent = `${sugg.text} (${new Date(sugg.timestamp).toLocaleString()})`;
                suggestionBox.appendChild(suggDiv);
            });
        } else {
            suggestionBox.textContent = 'No suggestions yet.';
        }
    } catch (error) {
        console.error('❌ Failed to load suggestions:', error);
        document.getElementById('suggestionBox').textContent = 'Failed to load suggestions.';
    }
}

// Submit suggestion
async function submitSuggestion() {
    if (!selectedUsername) {
        alert('Please select a user first!');
        return;
    }

    const suggestionInput = document.getElementById('suggestionInput');
    const suggestion = suggestionInput.value.trim();
    if (!suggestion) {
        alert('Suggestion cannot be empty!');
        return;
    }

    console.log('Submitting suggestion for user:', selectedUsername); // Debug log
    console.log('Suggestion content:', suggestion);

    try {
        const response = await fetch(`http://127.0.0.1:3000/api/sugg/${selectedUsername}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ suggestion }),
        });

        const result = await response.json();
        console.log('Response from server:', result); // Debug log

        if (response.ok) {
            // Clear input
            suggestionInput.value = '';
            // Refresh suggestions
            await loadSuggestions(selectedUsername);
        } else {
            alert(result.message || '❌ Failed to submit suggestion');
        }
    } catch (error) {
        console.error('❌ Failed to submit suggestion:', error);
        alert('❌ Failed to submit suggestion');
    }
}

// Check for new messages every 5 seconds
function startAutoRefresh() {
    setInterval(async () => {
        const users = Array.from(document.getElementById('userList').children).map(
            div => div.querySelector('span').textContent
        );
        for (const username of users) {
            await loadChatHistory(username, true);
        }
    }, 5000);
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Load user list
    loadUsers();

    // Start auto refresh
    startAutoRefresh();

    // Bind search event
    document.getElementById('searchUser').addEventListener('input', searchUsers);

    // Bind refresh chat event
    document.getElementById('refreshChat').addEventListener('click', () => {
        if (selectedUsername) {
            loadChatHistory(selectedUsername);
        }
    });

    // Bind send message event
    document.getElementById('sendMessage').addEventListener('click', sendMessage);

    // Bind submit suggestion event
    const submitSuggestionButton = document.getElementById('submitSuggestion');
    if (submitSuggestionButton) {
        submitSuggestionButton.addEventListener('click', () => {
            console.log('Submit suggestion button clicked'); // Debug log
            submitSuggestion();
        });
    } else {
        console.error('❌ Could not find submitSuggestion button');
    }

    // Send message on Enter key
    document.getElementById('messageInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });

    // Submit suggestion on Enter key
    document.getElementById('suggestionInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            console.log('Enter key pressed in suggestion input'); // Debug log
            submitSuggestion();
        }
    });
});