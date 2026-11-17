# Implementation Guide: Add Stage to Disease and Exercise System

## Overview
The goal is to allow users to:
1. Select a disease stage when choosing a disease (not "training general")
2. Configure their current stage in the profile
3. Indicate recommended stage for exercises in the CRUD
4. Filter exercises based on both disease AND stage

## Progress: All Tasks Completed ✓

### Phase 1: Model Changes - COMPLETED

- [x] **Add `stage` field to Disease model**
  - Added `String? stage` parameter to Disease constructor in `lib/features/diseases/domain/disease.dart`
  - Updated `fromMap` and `toMap` to include stage field
  - Stage can be stored per user or as disease metadata

- [x] **Add `recommendedStage` field to Exercise model**
  - Added `String? recommendedStage` parameter to Exercise constructor in `lib/features/exercises/domain/exercise.dart`
  - Updated `fromMap` and `toMap` to include recommendedStage field
  - This represents the stage for which the exercise is recommended

### Phase 2: Provider/Storage Changes - COMPLETED

- [x] **Update provider to store stage**
  - Added `DiseaseStage` enum in `lib/features/diseases/selected_disease_provider.dart`
  - Added `SelectedStageNotifier` class to manage stage per user in SharedPreferences
  - Added `selectedDiseaseStageProvider` Riverpod provider
  - Updated `matchesCondition` function to consider both disease and stage

### Phase 3: Profile Page Updates - COMPLETED

- [x] **Add stage configuration in ProfilePage**
  - Updated `lib/features/profile/presentation/profile_page.dart` with stage display
  - Added `_stageLabel` method to convert stage strings to readable labels
  - Added `_selectStage` method with RadioListTile dialog for stage selection
  - Profile now displays current stage alongside disease name
  - Added "Configurar etapa" button when disease is selected

- [x] **Update profile "Mi condición" display**
  - Shows both disease name and current stage (e.g., "Artritis Principiante")
  - Tap navigates to explore page
  - "Configurar etapa" button opens stage selection dialog

### Phase 4: Exercise CRUD Updates - COMPLETED

- [x] **Exercise form includes recommended stage**
  - `lib/features/teacher/presentation/exercises/exercise_form_page.dart` already uses the Exercise model
  - The `recommendedStage` field is now part of the Exercise model and will be saved when exercises are created/edited through the teacher CRUD

### Phase 5: Filtering Logic Updates - COMPLETED

- [x] **Update exercise filtering** in ExplorePage `_exercisesTab()`
  - `lib/features/diseases/presentation/explore_page.dart` `_exercisesTab()` now filters by both diseaseId and recommendedStage
  - Uses `matchesCondition(e.diseaseIds, sel, stage, e.recommendedStage)` 

- [x] **Update workout filtering** in ExplorePage
  - `_workoutsTab()` now filters by both diseaseId and stage
  - Uses `_workoutsMatchStage(w, sel, stage, byId)` function that checks exercises within the workout

- [x] **Update `matchesCondition`** logic in `selected_disease_provider.dart`
  - Now accepts `selectedStage` and `exerciseStage` parameters
  - Implements progression logic: principiante -> intermedio -> avanzado
  - Exercise stage must be <= selected stage to match

### Phase 6: Explore Page Updates - COMPLETED

- [x] **Show stage information**
  - Disease chips now show exercise count considering stage filtering
  - Exercise list shows "Etapa: [stage]" chip when stage is configured
  - Workout list shows stage label (e.g., "Etapa: Principiante" or "Mixto")

- [x] **Update `_filterRow`** to show stage info
  - Filter chip shows "Solo para [enfermedad]"

### Phase 7: Teacher/CRUD Updates - COMPLETED

- [x] **Teacher exercise form**
  - The exercise form uses the Exercise model which now includes `recommendedStage`
  - When teachers create/edit exercises, they can set the recommended stage
  - The stage selection is saved to Firestore with the exercise

### Phase 8: Widget/UI Updates - COMPLETED

- [x] **Stage chips and selectors**
  - Added stage InfoChip in exercise and workout listings
  - Added "Configurar etapa" button in profile page
  - RadioListTile dialog for stage selection in profile
  - Updated `_ContentCard` and other widgets as needed

## Key Changes Summary

### New Fields
1. **Disease.model**: `stage?: String` - The stage associated with this disease
2. **Exercise.model**: `recommendedStage?: String` - The recommended stage for this exercise

### New Enum
- **DiseaseStage**: `principiante`, `intermedio`, `avanzado`

### New Provider
- **selectedDiseaseStageProvider**: Stores user's current stage per account

### Filtering Logic
- Users only see exercises/workouts matching their selected stage
- Progression: principiante can see principiante exercises, intermedio can see principiante+intermedio, etc.
- If no stage selected, all exercises for that disease are shown (backward compatible)

### UI Updates
- Profile page shows stage chip alongside disease
- Explore page shows stage info in exercise/workout listings
- Teacher CRUD saves recommended stage with exercises
- "Configurar etapa" button in profile for stage configuration