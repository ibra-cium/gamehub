/**
 * GAME HUB - DATABASE AND CONTROLLER
 * 
 * To add a new game:
 * 1. Place the exported game build folder in this directory (e.g. `my-game/`).
 * 2. Add a new object to `GAMES_DATABASE` pointing to the HTML file.
 */

const GAMES_DATABASE = [
  {
    id: "rickshaw-rush",
    title: "Rickshaw Rush: Streets of Dhaka",
    description: "Navigate the busy streets of Dhaka in your rickshaw. Dodge traffic and transport passengers in this arcade game built with Godot.",
    category: "racing",
    players: "1 Player",
    path: "Rick crash/rikcrash.html",
    thumbnail: "Rick crash/rickshaw_rush_cover.png",
    featured: true
  },
  {
    id: "mountain-runner",
    title: "Mountain Runner",
    description: "Run and dodge obstacles across high-altitude mountain trails. Ride ziplines and collect coins in this endless runner built with Godot.",
    category: "platformer",
    players: "1 Player",
    path: "MountainRunner/MountainRunner.html",
    thumbnail: "MountainRunner/mountain_runner_cover.png",
    featured: false
  }
];

document.addEventListener("DOMContentLoaded", () => {
  // Select DOM Elements
  const gameGrid = document.getElementById("gameGrid");
  const searchInput = document.getElementById("searchInput");
  const filterButtons = document.querySelectorAll(".category-filters .arcade-btn");
  const activeCountEl = document.getElementById("activeCount");
  
  // Modal DOM Elements
  const modalOverlay = document.getElementById("modalOverlay");
  const gameIframe = document.getElementById("gameIframe");
  const cabinetTitle = document.getElementById("cabinetTitle");
  const cabinetLoading = document.getElementById("cabinetLoading");
  const btnCloseModal = document.getElementById("btnCloseModal");
  
  let currentCategory = "all";
  let searchQuery = "";
  let lastFocusedElement = null;

  // Initialize display counts
  if (activeCountEl) {
    activeCountEl.textContent = GAMES_DATABASE.length.toString();
  }

  // --- RENDER GAME CARDS ---
  function renderGames() {
    gameGrid.innerHTML = "";
    
    // Filter database
    const filteredGames = GAMES_DATABASE.filter(game => {
      const matchesCategory = currentCategory === "all" || game.category === currentCategory;
      const matchesSearch = game.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                            game.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            game.category.toLowerCase().includes(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    });

    if (filteredGames.length === 0) {
      gameGrid.innerHTML = `
        <div class="no-results">
          <div class="no-results-icon">🔍</div>
          <p>No games found matching your search.</p>
        </div>
      `;
      return;
    }

    filteredGames.forEach(game => {
      const card = document.createElement("article");
      card.className = "game-card";
      
      card.innerHTML = `
        <div class="game-thumbnail-wrapper">
          <img src="${game.thumbnail}" alt="${game.title}" class="game-thumbnail" loading="lazy">
          <span class="game-genre-badge">${game.category}</span>
        </div>
        <div class="game-info">
          <h2 class="game-title">${game.title}</h2>
          <p class="game-description">${game.description}</p>
          <div class="game-meta">
            <span class="game-players">${game.players}</span>
            <button class="game-play-btn" data-id="${game.id}">Play Game</button>
          </div>
        </div>
      `;

      gameGrid.appendChild(card);
    });

    // Attach click listeners to Play buttons
    const playButtons = gameGrid.querySelectorAll(".game-play-btn");
    playButtons.forEach(btn => {
      btn.addEventListener("click", (e) => {
        lastFocusedElement = e.currentTarget;
        const gameId = e.currentTarget.getAttribute("data-id");
        launchGame(gameId);
      });
    });
  }

  // --- LAUNCH GAME ---
  function launchGame(gameId) {
    const game = GAMES_DATABASE.find(g => g.id === gameId);
    if (!game) return;
    
    // Set UI elements
    if (cabinetTitle) {
      cabinetTitle.textContent = game.title;
    }
    cabinetLoading.classList.remove("hidden");
    gameIframe.removeAttribute("src"); // Clear first to ensure fresh reload
    
    // Open modal container
    modalOverlay.classList.add("active");
    modalOverlay.setAttribute("aria-hidden", "false");
    
    // Set iframe path and show
    setTimeout(() => {
      gameIframe.src = game.path;
    }, 100);

    // Hide loader once the Godot engine completes loading
    gameIframe.onload = () => {
      setTimeout(() => {
        cabinetLoading.classList.add("hidden");
        gameIframe.focus();
      }, 500);
    };
  }

  // --- CLOSE MODAL ---
  function closeModal() {
    modalOverlay.classList.remove("active");
    modalOverlay.setAttribute("aria-hidden", "true");
    
    // Stop the game entirely by removing src
    gameIframe.src = "about:blank"; 
    
    // Return focus
    if (lastFocusedElement) {
      lastFocusedElement.focus();
    }
  }

  // Close modal button trigger
  btnCloseModal.addEventListener("click", closeModal);

  // Keyboard navigation inside modal (close on ESC)
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && modalOverlay.classList.contains("active")) {
      closeModal();
    }
  });

  // Keep focus within modal when active (Focus Trap)
  modalOverlay.addEventListener("keydown", (e) => {
    if (!modalOverlay.classList.contains("active")) return;
    
    const focusables = modalOverlay.querySelectorAll("button, iframe");
    const firstFocusable = focusables[0];
    const lastFocusable = focusables[focusables.length - 1];

    if (e.key === "Tab") {
      if (e.shiftKey) { // Shift + Tab
        if (document.activeElement === firstFocusable) {
          lastFocusable.focus();
          e.preventDefault();
        }
      } else { // Tab
        if (document.activeElement === lastFocusable) {
          firstFocusable.focus();
          e.preventDefault();
        }
      }
    }
  });

  // --- SEARCH BAR CONTROLLER ---
  searchInput.addEventListener("input", (e) => {
    searchQuery = e.target.value;
    renderGames();
  });

  // --- CATEGORY FILTERS CONTROLLER ---
  filterButtons.forEach(btn => {
    btn.addEventListener("click", (e) => {
      // Toggle active states
      filterButtons.forEach(b => b.classList.remove("active"));
      e.currentTarget.classList.add("active");
      
      currentCategory = e.currentTarget.getAttribute("data-category");
      renderGames();
    });
  });

  // --- INITIAL RENDERING ---
  renderGames();
});
