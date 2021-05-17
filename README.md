# FluentSQLite
 An implementation of SQLite Query Builder in D Lang, originally ported from [fluks](https://github.com/segabond/fluks) in Kotlin.

## Usage
```D
import taskdesigns.sqlite;

// Define a table
auto users = new Table("users");

// Creating a table example
users.create( (it) {
    auto id = new Column!int("id");
    auto name = new Column!string("name");
    auto email = new Column!string("email");
    it.column(id, true, false, true);
    it.column(name);
    it.column(email);
}).asSQL();

// Insert statement example
users.insert( (it) {
    auto name = new Column!string("name");
    auto email = new Column!string("email");
    it[name] = "John Smith";
    it[email] = "john.smith@example.com";
}).asSQL();

// Select query example
auto email = new Column!string("email");
users.select().where(email.eq("john.smith@example.com")).asSQL();

```


## Installation
Dub Manually:
```manual
dub add fluentsqlite
```
Dub SDL:
```sdl
dependency "fluentsqlite" version="~>0.1.1"
```
Dub JSON:
```json
"fluentsqlite": "~>0.1.1"
```
