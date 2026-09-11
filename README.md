# 🚀 Vortex Runner

Prototype de jeu 3D Android/PC réalisé avec **Godot 4**.

Le joueur pilote un vaisseau en vue arrière / 3⁄4 à travers un tunnel lumineux de type vortex et doit éviter les obstacles tandis que la vitesse augmente progressivement.

## État actuel

- tunnel 3D procédural lumineux ;
- vaisseau et caméra arrière / 3⁄4 ;
- contrôles tactiles Android ;
- contrôles souris et clavier sur PC ;
- obstacles générés et recyclés ;
- collisions ;
- accélération progressive ;
- score ;
- game over et redémarrage.

## Lancer le jeu sur PC

1. Installer Godot 4.x.
2. Cloner le dépôt.
3. Ouvrir `project.godot` dans Godot.
4. Lancer le projet avec **F6/F5**.

### Contrôles

- **Clavier :** WASD ou flèches.
- **Souris :** maintenir le clic et déplacer.
- **Android :** glisser le doigt pour piloter.

## Android

Dans Godot :

1. installer les Android Build Templates si nécessaire ;
2. configurer le SDK Android et le JDK dans `Editor > Editor Settings > Export > Android` ;
3. activer le débogage USB sur le téléphone ;
4. ajouter un preset dans `Project > Export > Android` ;
5. exporter en APK pour les tests ou en AAB pour une future publication.

## Roadmap

- [x] vrai modèle de vaisseau ;
- [ ] réacteurs et particules ;
- [x] sensation de vitesse renforcée ;
- [x] tunnel courbe / vortex plus organique ;
- [x] plusieurs types d'obstacles ;
- [x] bonus et pickups ;
- [x] sons et musique ;
- [x] menu principal ;
- [x] meilleur score sauvegardé ;
- [ ] optimisation Android ;
- [x] export APK/AAB automatisé.

## Gameplay

- **Menu principal** : le tunnel défile en fond, le meilleur score s'affiche, on
  lance la partie avec **JOUER**.
- **Montée de difficulté** : plus la distance augmente, plus les obstacles se
  rapprochent (densité) et la vitesse de pointe grimpe.
- **Bonus / pickups** :
  - **orbe dorée** — points + multiplicateur de combo (jusqu'à ×7) qui décroît
    si l'on cesse d'en ramasser ;
  - **bouclier ◈ (vert)** — encaisse un choc au lieu de la mort (courtes
    i-frames + bulle protectrice).
- **Meilleur score** sauvegardé localement (`user://scores.cfg`).
- **Game over** : score, record et « nouveau record », **rejouer en un tap**.

## Moteur

Godot 4 — rendu `gl_compatibility` afin de garder une bonne compatibilité avec les appareils Android.
