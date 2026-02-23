# Photo Organizer App

## Overview
The Photo Organizer App is a Flutter application designed to help users organize their photos into collections using Google Photos. The app provides a user-friendly interface for browsing, managing, and viewing photos.

## Features
- Organize photos into collections
- View detailed information about each photo
- Easy navigation between collections and photo details
- Integration with Google Photos API for fetching collections and photos

## Project Structure
```
photo_organizer_app
├── lib
│   ├── main.dart
│   ├── screens
│   │   ├── home_screen.dart
│   │   ├── collection_screen.dart
│   │   └── photo_detail_screen.dart
│   ├── services
│   │   ├── google_photos_service.dart
│   │   └── photo_service.dart
│   ├── models
│   │   ├── photo.dart
│   │   ├── collection.dart
│   │   └── user.dart
│   ├── widgets
│   │   ├── photo_grid.dart
│   │   ├── collection_card.dart
│   │   └── app_bar.dart
│   └── utils
│       └── constants.dart
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
└── README.md
```

## Setup Instructions
1. Clone the repository:
   ```
   git clone <repository-url>
   ```
2. Navigate to the project directory:
   ```
   cd photo_organizer_app
   ```
3. Install the dependencies:
   ```
   flutter pub get
   ```
4. Run the app:
   ```
   flutter run
   ```

## Usage
- Launch the app to view the home screen.
- Navigate through collections to view and manage your photos.
- Select a photo to view its details and options for editing or sharing.

## Contributing
Contributions are welcome! Please feel free to submit a pull request or open an issue for any enhancements or bug fixes.

## License
This project is licensed under the MIT License. See the LICENSE file for details.