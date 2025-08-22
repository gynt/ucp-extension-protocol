# Protocol extension
This extension provides a system for interacting with the game's synchronization protocol and extending it.

Game's run in a simulation, and to play multiplayer, each peer runs its own simulation.

Almost all communication between peers runs through a protocol that ensures each machine applies changes to the simulation such as placing a building, at the exact same time (game tick).

For documentation, see [here](https://gynt.github.io/ucp-extension-protocol).
