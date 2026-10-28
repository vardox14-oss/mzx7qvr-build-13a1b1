# DarkGPT iOS — installer l'appli sur ton iPhone

Appli **native** (SwiftUI) connectée au serveur darkgpt.chat : connexion (email, Google, Discord), chat en direct, choix du modèle, historique, images.

L'`.ipa` produit n'est **pas signé** (pas de compte Apple Developer payant). Il s'installe par « sideload ». Deux méthodes.

## Récupérer l'`.ipa`
1. Sur GitHub → onglet **Actions** → dernier run **Build DarkGPT iOS** → section **Artifacts** → télécharge `DarkGPT-ios-ipa` (c'est un .zip qui contient `DarkGPT-unsigned.ipa`).

## Méthode A — AltStore (recommandée, re-signe tout seul)
1. Installe **AltServer** sur ton PC Windows : altstore.io.
2. Branche ton iPhone en USB, ouvre iTunes (ou Appareils Apple), autorise l'appareil.
3. AltServer (icône barre des tâches) → **Install AltStore** → choisis ton iPhone → entre ton **identifiant Apple** (un compte gratuit suffit).
4. Sur l'iPhone : **Réglages → Général → VPN et gestion de l'appareil** → fais confiance à ton profil.
5. Ouvre **AltStore** sur l'iPhone → onglet **My Apps** → **+** en haut → choisis `DarkGPT-unsigned.ipa`.
6. AltStore re-signe et installe. ⚠️ Avec un compte gratuit, l'appli expire après **7 jours** : rouvre AltStore pour la renouveler (AltServer doit tourner sur le PC, même réseau Wi-Fi).

## Méthode B — Sideloadly
1. Installe **Sideloadly** : sideloadly.io. Branche l'iPhone.
2. Glisse l'`.ipa`, entre ton identifiant Apple, clique **Start**.
3. Fais confiance au profil : **Réglages → Général → VPN et gestion de l'appareil**.

## Activer le mode développeur (iOS 16+)
Obligatoire une seule fois pour lancer une appli sideloadée :
1. Installe l'appli d'abord (sinon l'option n'apparaît pas).
2. **Réglages → Confidentialité et sécurité** → tout en bas → **Mode développeur** → active.
3. L'iPhone redémarre → au redémarrage, confirme **Activer**.
4. Ouvre DarkGPT.

## Notes
- Le compte, les gems et les offres sont **les mêmes que sur le site**.
- La connexion **Google/Discord** nécessite la dernière version du serveur déployée (endpoints `/mobile/auth`). La connexion **email + mot de passe** marche avec le site actuel.
- L'historique des conversations est stocké **sur le téléphone** (comme le site le fait dans le navigateur).
