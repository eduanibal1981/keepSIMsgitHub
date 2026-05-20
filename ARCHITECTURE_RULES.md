# Flutter Clean Architecture Rules
# Stack: Flutter + Supabase + Riverpod + Freezed

## Overview

This project follows a strict 5-layer clean architecture.
Every new feature MUST follow these rules exactly.
No exceptions. No shortcuts.

---

## Layer Order (always build in this sequence)

```
model → contract → repository → controller → ui
```

Never skip a layer. Never merge two layers into one file.

---
## Project Structure

```text
lib/
├── core/
│   ├── failure.dart          ← Freezed union of all error types
│   ├── result.dart           ← Dart 3 sealed class (Success / Failure)
│   ├── supabase_client.dart  ← global supabase getter + initSupabase()
│   └── providers.dart        ← all Riverpod repository providers
│
└── features/
    └── {feature_name}/
        ├── model/
        │   └── {name}_model.dart
        ├── contract/
        │   └── {name}_contract.dart
        ├── repository/
        │   └── {name}_repository.dart
        ├── controller/
        │   └── {name}_controller.dart
        └── ui/
            └── {name}_screen.dart
```
### Debug Rules 
- Do not use run_command (Python, bash, or terminal commands) to read, search, or edit files. You must strictly use the native view_file, grep_search, and file editing tools for codebase navigation.
---

### Layer 1 — Model Rules

**File:** `model/{name}_model.dart`

MUST:
- Annotate with `@freezed`
- Annotate with `@JsonSerializable(fieldRename: FieldRename.snake)` to handle Supabase column mapping automatically.
- Implement `with _$ClassName`
- Include `factory ClassName.fromJson(Map<String, dynamic> json) => _$ClassNameFromJson(json);`
- Add `part '{name}_model.freezed.dart';`
- Add `part '{name}_model.g.dart';`
- Use only pure Dart types (String, int, DateTime, List, etc.)
- Name generated union classes with underscore prefix e.g. `= _ClassName`

MUST NOT:
- Import supabase_flutter
- Import flutter
- Import riverpod
- Contain any business logic
- Contain any API calls

IMPORTS ALLOWED:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'other_model.dart'; // only other models
```

IF model has a nested union type (e.g. status enum):
- Define a `JsonConverter` for it in the same file
- Use `@ConverterName()` annotation on the field
- Never rely on freezed to auto-serialize union types

EXAMPLE:
```dart
@freezed
@JsonSerializable(fieldRename: FieldRename.snake)
class Employee with _$Employee {
  const factory Employee({
    required String id,
    required String fullName,
    required String email,
    @Default([]) List<Job> jobs,
  }) = _Employee;

  factory Employee.fromJson(Map<String, dynamic> json) =>
      _$EmployeeFromJson(json);
}
```

---

## Layer 2 — Contract Rules

**File:** `contract/{name}_contract.dart`

MUST:
- Be an `abstract interface class`
- Define all possible operations as method signatures
- Return `Future<Result<T>>` for every method
- Never contain implementation

MUST NOT:
- Import supabase_flutter
- Import flutter
- Import riverpod
- Contain any logic whatsoever

IMPORTS ALLOWED:
```dart
import '../model/{name}_model.dart';
import '../core/result.dart';
```

STANDARD CRUD SIGNATURES:
```dart
abstract interface class NameContract {
  Future<Result<List<Model>>> getAll();
  Future<Result<Model>> getById(String id);
  Future<Result<Model>> create(Model model);
  Future<Result<Model>> update(Model model);
  Future<Result<void>> delete(String id);
}
```

Add non-CRUD methods when needed e.g.:
```dart
Future<Result<List<Job>>> getByEmployee(String employeeId);
```

---

## Layer 3 — Repository Rules

**File:** `repository/{name}_repository.dart`

MUST:
- Implement the contract: `class XRepository implements XContract`
- Accept `SupabaseClient` via constructor
- Wrap every method in try/catch
- Always return `Success(data)` or `Failure(Failure.x())`
- Handle specific `PostgrestException` codes explicitly
- Rely entirely on `model.toJson()` and `Model.fromJson()` for data mapping

MUST NOT:
- Import flutter
- Import riverpod
- Contain UI logic
- Write manual JSON mapping helpers (e.g., _toInsertJson) — let Freezed handle it.

IMPORTS ALLOWED:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../contract/{name}_contract.dart';
import '../model/{name}_model.dart';
import '../core/result.dart';
import '../core/failure.dart';
```

POSTGREST ERROR CODES TO HANDLE:
| Code     | Meaning                     | Use                       |
|----------|-----------------------------|---------------------------|
| PGRST116 | Row not found (.single())   | Failure.notFound()        |
| 23505    | Unique constraint violation | Failure.validation()      |
| default  | Any other postgres error    | Failure.server(e.message) |

JSON MAPPING PATTERN:
- Supabase stores `snake_case` columns.
- Models use `camelCase` fields.
- Freezed handles the conversion automatically via `@JsonSerializable(fieldRename: FieldRename.snake)`.
- ALWAYS use `toJson()` for DB inserts and updates.
- ALWAYS use `fromJson()` for DB reads.
- NEVER write manual `Map<String, dynamic>` converters.

```dart
// CORRECT (Insert/Update)
await _client.from('jobs').insert(job.toJson());

// CORRECT (Read)
final response = await _client.from('jobs').select().eq('id', id).single();
return Success(Job.fromJson(response));

// WRONG
// Manually mapping keys like { 'employee_id': job.employeeId }
```

---
## Layer 4 — Controller Rules

**File:** `controller/{name}_controller.dart`

MUST:
- Annotate with `@riverpod`
- Extend `_$NameController`
- Get repository via `ref.read(repositoryProvider)` — always use contract type
- Add `part '{name}_controller.g.dart';`
- Controllers MUST initialize data by overriding the `build()` method (returning `FutureOr<T>`).
- Manage state exclusively through Riverpod's native `AsyncValue` (do not create custom Freezed states).
- Use Dart 3 `switch` statements for exhaustive pattern matching on `Result` types.
- Extract data and errors directly from the matched case to avoid null-bang (`!`) operators.

MUST NOT:
- Import supabase_flutter
- Import flutter
- Contain BuildContext
- Contain navigation logic
- Create custom `@freezed` state classes for the controller.
- Use `isSuccess` or `isFailure` boolean checks followed by null-bang operators (`dataOrNull!`).

INITIALIZATION PATTERN (build method):
```dart
@riverpod
class NameController extends _$NameController {
  @override
  FutureOr<List<Model>> build() async {
    // This runs automatically the first time the UI watches this provider.
    return _fetchAll(); 
  }

  Future<List<Model>> _fetchAll() async {
    final repo = ref.read(nameRepositoryProvider);
    final result = await repo.getAll();
    
    // Dart 3 Sealed classes for Result:
    return switch (result) {
      Success(data: final items) => items,
      // Riverpod catches thrown exceptions and automatically sets state to AsyncError
      Failure(error: final e) => throw Exception(e.readableMessage), 
    };
  }
}
```
RESULT HANDLING PATTERN (For mutations/actions):
```dart
// CORRECT (Dart 3 Pattern Matching)
Future<void> create(Model item) async {
  // Optional: Set state to loading while mutating
  // state = const AsyncValue.loading(); 
  
  final result = await ref.read(nameRepositoryProvider).create(item);
  
  switch (result) {
    case Success(data: final _): 
      ref.invalidateSelf(); // clean background refresh after mutation
    case Failure(error: final f):
      state = AsyncValue.error(f.readableMessage, StackTrace.current);
  }
}

// WRONG
if (result.isSuccess) {
  final data = result.dataOrNull!; // Never do this
}
```

IMPORTS ALLOWED:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../contract/{name}_contract.dart';
import '../model/{name}_model.dart';
import '../core/result.dart';
import '../core/providers.dart';
```

STATE PATTERN:
Controllers MUST manage state using Riverpod's built-in AsyncValue<T>.


AFTER MUTATING (create/update/delete):
- MUST trigger a background refresh using `ref.invalidateSelf()` (or `ref.invalidate(provider)` from the UI).
- MUST NOT manually call fetch/load methods (like `loadAll()`) after a mutation.
- MUST NOT rely solely on local state updates (always invalidate to sync with DB).

Pattern:
```dart
// Inside controller mutation method:
switch (result) {
  case Success():
    ref.invalidateSelf(); // Riverpod will silently re-run build() in the background
  case Failure(error: final f):
    state = AsyncValue.error(f.readableMessage, StackTrace.current);
}
```
---

## Layer 5 — UI Rules

**File:** `ui/{name}_screen.dart`

MUST:
- Extend `ConsumerWidget` or `ConsumerStatefulWidget`
- Use `ref.watch()` for state
- Use `ref.read(provider.notifier)` for actions
- UI MUST NEVER trigger initial data loads. Controllers MUST initialize data in their `build()` method. UI solely watches the state.
- Handle all `AsyncValue` states: data, loading, error
- Make `_submit()` async and `await` the notifier call before `Navigator.pop()`
- Use `ref.invalidate(controllerProvider)` to trigger a clean background refresh after mutations or errors.
- Check `mounted` before calling Navigator after async gap

MUST NOT:
- Contain business logic
- Call Supabase directly
- Import supabase_flutter
- Import repository files
- UI MUST NOT manually trigger initial loads. Use ref.watch() and handle Riverpod's built-in AsyncValue states (data, loading, error).

IMPORTS ALLOWED:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/{name}_controller.dart';
import '../model/{name}_model.dart';
```


SUBMIT PATTERN (bottom sheet):
```dart
void _submit() async {
  if (!_formKey.currentState!.validate()) return;

  final notifier = ref.read(nameControllerProvider.notifier);
  await notifier.create(item); // Controller handles its own state invalidation

  if (mounted) {
    Navigator.pop(context); // Just pop. Riverpod handles the background refresh.
  }
}
```

PRIVATE WIDGET CLASSES:
- Helper widgets inside a screen file should NOT use underscore prefix
- Use `class JobCard` not `class _JobCard` to avoid analyzer scope issues

STATE RENDERING PATTERN:
```dart
// Inside your ConsumerWidget's build method
final state = ref.watch(nameControllerProvider);

return state.when(
  data: (items) => items.isEmpty
      ? const EmptyView()
      : ItemList(items: items),
  loading: () => const CircularProgressIndicator(),
  error: (error, stackTrace) => ErrorView(
    message: error.toString(), 
    onRetry: () => ref.invalidate(nameControllerProvider), // Clean refresh
  ),
);

---

## Core Files Rules

### `core/failure.dart`
- Never add new failure types without adding `readableMessage` handling
- Current types: server, network, notFound, unknown, validation

### `core/result.dart`
- MUST be a Dart 3 `sealed class`.
- MUST NOT use Freezed.
- Pattern to use:
```dart
sealed class Result<T> {}
class Success<T> extends Result<T> { 
  final T data; 
  Success(this.data); 
}
class Failure<T> extends Result<T> { 
  final FailureType error; // Your core/failure.dart union
  Failure(this.error); 
}
```

### `core/supabase_client.dart`
- Only file allowed to import and initialize Supabase
- Exposes a single `supabase` global getter

### `core/providers.dart`
- Every new repository MUST be registered here
- Pattern:
```dart
@riverpod
XContract xRepository(Ref ref) => XRepository(supabase);
```

---

## Supabase Schema Rules
- use file mcp_supabase_setup.md to connect to the supabase project, if the file is not present ask the user to create one
- use supabase mcp to create tables, views, functions, and triggers
- use supabase mcp to migrate and update the schema
- use supabase mcp to drop tables, views, functions, and triggers
- use supabase mcp to sync and update the schema
- use supabase mcp to create indexes
- use supabase mcp to create constraints
- use supabase mcp to drop indexes
- use supabase mcp to drop constraints

Every table MUST follow this column naming:
- All columns: `snake_case`
- Primary key: `id UUID DEFAULT gen_random_uuid()`
- Foreign keys: `{relation}_id UUID REFERENCES {table}(id) ON DELETE CASCADE`
- Timestamps: `created_at TIMESTAMPTZ DEFAULT NOW()`
- Enums stored as: `TEXT` with `CHECK` constraint

SCHEMA TEMPLATE:
```sql
CREATE TABLE {name} (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  -- your columns in snake_case
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_{name}_{fk_column} ON {name}({fk_column});

NOTIFY pgrst, 'reload schema'; -- run after any schema change
```
---

## Code Generation

Run after ANY model/controller change:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Files that need generation (never edit these manually):
- `*.freezed.dart`
- `*.g.dart`

---

## Adding a New Feature Checklist

```text
[ ] 1. Define Supabase table with snake_case columns
[ ] 2. Create model with @freezed
      - MUST include @JsonSerializable(fieldRename: FieldRename.snake)
      - add JsonConverter if nested union
[ ] 3. Create contract with Result<T> return types
[ ] 4. Create repository implementing contract
      - use model.toJson() for inserts/updates
      - use Model.fromJson() for reading data
      - try/catch every method
[ ] 5. Register repository in core/providers.dart
[ ] 6. Create controller with @riverpod
      - extend _$NameController
      - initialize data in build() method
      - use Dart 3 switch for Result pattern matching
[ ] 7. Create UI screen
      - ConsumerWidget (or ConsumerStatefulWidget if form is needed)
      - UI MUST NEVER trigger initial data loads (solely watch state)
      - Handle AsyncValue states: data, loading, error
      - Use ref.invalidate() for refreshing data
[ ] 8. Run build_runner
[ ] 9. Run NOTIFY pgrst, 'reload schema' in Supabase SQL editor

---

## Import Allowed Matrix

| Layer      | freezed | riverpod | supabase | flutter | model | contract | core |
|------------|---------|----------|----------|---------|-------|----------|------|
| model      | YES     | NO       | NO       | NO      | YES   | NO       | NO   |
| contract   | NO      | NO       | NO       | NO      | YES   | NO       | YES  |
| repository | NO      | NO       | YES      | NO      | YES   | YES      | YES  |
| controller | YES     | YES      | NO       | NO      | YES   | YES      | YES  |
| ui         | NO      | YES      | NO       | YES     | YES   | NO       | NO   |

---

## Common Mistakes Reference

| Mistake | Fix |
|--------|-----|
| Using `result.isSuccess` with `!` | Use Dart 3 `switch (result)` for exhaustive matching |
| Manually mapping JSON for Supabase | Use `model.toJson()` and let Freezed handle `snake_case` |
| Manually calling `loadAll()` after mutation | Use `ref.invalidateSelf()` inside the controller mutation |
| `class _Widget` private helper | Remove underscore, use `class Widget` |
| `JobStatus` union not serializing | Add `JsonConverter` in model file |
| Schema cache error in Supabase | Run `NOTIFY pgrst, 'reload schema'` |
| Union variants without underscore | Use `= _VariantName` not `= VariantName` |
| UI triggering data load (e.g., `initState`) | Controllers initialize data in `build()`. UI solely watches the state. |