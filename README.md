<div align="center">

  # 💎 Kapi Finance
  ### Gestion de Budget Mensuel & Portfolio d'Investissement Multi-Actifs

  [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)
  [![Yahoo Finance](https://img.shields.io/badge/Yahoo_Finance_API-6001D2?style=for-the-badge&logo=yahoo&logoColor=white)](https://finance.yahoo.com/)
  

  <br />

  **Une application financière moderne, combinant suivi mensuel de dépenses (récurrentes ou ponctuelles) et stratégies d'investissement passif (DCA, Bankroll...).**

  <br />

  [🚀 Tester l'application en ligne](https://kapi-finance.web.app) • [✨ Fonctionnalités](#-fonctionnalités-clés) • [🛠️ Architecture](#-stack-technique) • [📱 Aperçus](#-aperçus-de-lapplication)

</div>

---

## 📌 Présentation du Projet

**Kapi Finance** est né d'un constat simple : Je n'ai trouvé aucune application sur le marché qui me permettent de calculer combien j'au d'argent sur mon compte, en comptant les dépenses effectuées qui ne sont pas encore passée (et qui parfois peuvent prendre plusieurs jours ou semaine comme Amazon). De plus la plupart des applications financières séparent la gestion des dépenses quotidiennes du pilotage des investissements en bourse et cryptomonnaies.

L'objectif de Kapi est d'unifier ces deux piliers au sein d'une seule interface au design **Dark Luxury**, fluide et sécurisée :
1. **Piloter sa trésorerie mensuelle** : Anticiper le solde bancaire réel à chaque cycle de paie.
2. **Optimiser son épargne investie** : Suivre ses comptes (PEA, CTO, Livrets, Crypto), automatiser ses achats programmés et suivre les cours mondiaux en direct.

---

## 📱 Aperçus de l'Application

<div align="center">
  <table>
    <tr>
      <td align="center"><b>📊 Synthèse du Patrimoine</b></td>
      <td align="center"><b>💰 Gestion du Budget Mensuel</b></td>
      <td align="center"><b>⚙️ Stratégie & Allocation</b></td>
    </tr>
    <tr>
      <td><img src="screenshots/patrimoine.png" width="260" alt="Écran Patrimoine"/></td>
      <td><img src="screenshots/budget.png" width="260" alt="Écran Budget"/></td>
      <td><img src="screenshots/settings.png" width="260" alt="Paramètres & Allocations"/></td>
    </tr>
  </table>
</div>

---

## ✨ Fonctionnalités Clés

### 💰 1. Kapi Budget (Gestion de Trésorerie)
- **Double Vision Financière** :
  - **Planification Théorique** : Revenus estimés vs Dépenses engagées.
  - **Trésorerie Réelle** : Solde bancaire réel en temps réel et projection exacte du solde en fin de mois.
- **Cycle de Paie Personnalisé** : Choix du jour de début de mois avec réinitialisation automatique des charges récurrentes.
- **Tri & Gestion Intuitive** :
  - Classement dynamique des dépenses de la plus coûteuse à la plus faible.
  - Suivi des statuts : `Payé` / `À payer` en un clic.
  - Possibilité d'inclure ou d'exclure temporairement une dépense des calculs.
  - Menu contextuel fluide par appui long (Modification, Exclusion, Suppression).

### 📈 2. Kapi Invest (Portfolio & Stratégie Patrimoniale)
- **Arborescence Réaliste** : `Établissement (Courtier / Banque)` ➔ `Enveloppe (PEA, CTO, Livret, Crypto)` ➔ `Actifs`.
- **Intégration Yahoo Finance en Direct** :
  - Recherche universelle instantanée par **Nom**, **Ticker** ou code **ISIN**.
  - Actualisation des cours mondiaux et calcul instantané des plus-values latentes (€ et %).
- **Courbes & Graphiques Interactifs (`fl_chart`)** :
  - Graphique consolidé du patrimoine global.
  - Graphiques de performance dépliables pour chaque établissement et pour chaque actif individuel.
  - Curseur d'inspection précis avec **date, heure et montant au centime près**.
- **Deux Modes d'Investissement Stratégiques** :
  - 🔹 **Profil 1 (Budget Fixe & Bankrolls)** : Allocation en pourcentage du budget mensuel. Les fonds s'accumulent dans des tirelires virtuelles dédiées jusqu'à ce qu'une part entière puisse être achetée.
  - 🔸 **Profil 2 (DCA en Parts Réelles)** : Fixation d'objectifs en parts (ex: 1 part S&P 500 + 1 part Nasdaq) avec adaptation automatique de l'effort d'épargne aux fluctuations du marché.

---

## 🛠️ Stack Technique

| Domaine | Technologies |
|---|---|
| **Frontend** | [Flutter](https://flutter.dev/) (Dart) • Architecture Réactive multiplateforme (Web, Desktop, Mobile) |
| **Data Viz** | [fl_chart](https://pub.dev/packages/fl_chart) (Graphiques vectoriels interactifs haute performance) |
| **Backend & Auth** | [Firebase Authentication](https://firebase.google.com/docs/auth) (Gestion sécurisée des comptes utilisateurs) |
| **Base de Données** | [Cloud Firestore](https://firebase.google.com/docs/firestore) (Synchronisation NoSQL en temps réel avec stratégie de snapshot économique) |
| **Hébergement** | [Firebase Hosting](https://firebase.google.com/docs/hosting) (Déploiement mondial CDN rapide et SSL) |
| **API Financière** | [Yahoo Finance API](https://finance.yahoo.com/) (Données de marché en direct & historique sur 1 an) |

---

## 🚀 Utilisation de la webapp en mode client

### Prérequis
- Un navigateur web (Chrome, Safari, Firefox, Eplorer...) 

### Accès
https://kapi-finance.web.app/

## 🌐 Déploiement & Mise en Production
Commandes utilisées pour publier la web app:
```bash
# 1. Compiler l'application Flutter en version Web optimisée
flutter build web --release

# 2. Déployer sur Firebase Hosting
firebase deploy --only hosting
```
## 🔒 Sécurité & Bonnes Pratiques
Authentification sécurisée : Délégation complète de la gestion des identifiants et des sessions à Firebase Auth (tokens JWT sécurisés).

- Architecture Single Document (Firestore) : Optimisation des quotas réseau pour minimiser les lectures/écritures et garantir des temps de chargement quasi-instantanés.

- Isolation des utilisateurs : Chaque compte n'a accès qu'à son propre espace de données via des règles de sécurité Firestore strictes (request.auth.uid == userId).

- Contournement CORS maîtrisé : Relais d'API proxy transparent pour garantir les requêtes Yahoo Finance en environnement navigateur (Web).

## 🗺️ Roadmap & Évolutions Futures
[ ] Connexion bancaire automatisée via API Open Banking (Agrégation en direct).

[ ] Export comptable des dépenses et de l'historique d'investissement en PDF / CSV.

[ ] Alertes push lors du franchissement de seuils d'achat de parts (Profil 1).

[ ] Déploiement d'applications mobiles natives (Android APK / iOS via App Store).


## 👨‍💻 Auteur & Contact
Développé par Ryan Barrault, Fan d'applications utiles quotidienne, d'applications de jeux et d'animation(informatique graphique)

GitHub : @Rbyaarnrault

LinkedIn : www.linkedin.com/in/ryan-barrault-57090b1a2
