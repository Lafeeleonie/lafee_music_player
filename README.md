# Lafee Music Player

Addon WoW pour lire des musiques en jeu depuis une playlist, avec une musique speciale qui se lance quand une BL/Heroism/Time Warp est detectee.

L'addon ajoute aussi un bouton sur la minimap et une petite fenetre de controle deplacable avec lecture/pause, precedent/suivant, mode normal/aleatoire, volume et titre de la piste en cours.

## Dossiers

- `playlist` : mets ici les musiques de ta playlist normale.
- `bl` : mets ici la musique speciale BL.

WoW ne permet pas a un addon de scanner automatiquement les fichiers d'un dossier. Chaque musique doit donc etre ajoutee dans `playlist.lua`.
Tu peux aussi lancer `update_playlist.ps1` depuis PowerShell pour regenerer cette liste automatiquement.

## Configuration

Exemple dans `playlist.lua` :

```lua
LafeeMusicPlayerTracks = {
    "Interface\\AddOns\\Lafee_music_player\\playlist\\musique1.mp3",
    "Interface\\AddOns\\Lafee_music_player\\playlist\\musique2.ogg",
}

LafeeMusicPlayerBLTrack = "Interface\\AddOns\\Lafee_music_player\\bl\\bloodlust.mp3"
```

Apres modification, tape `/reload` en jeu.

Pour regenerer automatiquement la liste apres avoir ajoute des fichiers, double-clique sur `update_playlist.bat`.

Tu peux aussi lancer la commande directement :

```powershell
powershell -ExecutionPolicy Bypass -File .\update_playlist.ps1
```

## Commandes

- `/lmp play` : lancer la playlist
- `/lmp pause` : mettre en pause, puis reprendre au debut de la piste
- `/lmp stop` : arreter la lecture
- `/lmp next` : musique suivante
- `/lmp prev` : musique precedente
- `/lmp random` : lecture aleatoire
- `/lmp normal` : lecture dans l'ordre
- `/lmp bl` : tester la musique BL
- `/lmp show` : afficher ou cacher la fenetre

Le bouton minimap utilise les bibliotheques LibDataBroker/LibDBIcon embarquees avec l'addon. Le clic gauche affiche/cache la fenetre. Le clic droit fait play/pause.

Note : l'API audio de WoW ne permet pas une vraie pause au milieu d'un fichier. Le bouton pause arrete la piste, puis play la relance depuis le debut.

Les formats `mp3` et `ogg` sont les plus pratiques pour WoW.
