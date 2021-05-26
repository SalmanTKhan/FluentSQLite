# FluentSQLite
 An implementation of SQLite Query Builder in D Lang, originally ported from [fluks](https://github.com/segabond/fluks) in Kotlin.

## Usage
```D
import taskdesigns.sqlite;

// Define a table
auto users = new Table("users");

// Drop table
users.drop().asSQL();

// Create a table example (only creates if table doesn't exist)
users.create( (it) {
    auto id = new Column!int("id"); // Create a column called id of type int
    auto name = new Column!string("name"); // Create a column called name of type string
    auto email = new Column!string("email"); // Create a column called email of type string
    it.column(id, true, false, true); // Add a column to this table which is a primary key, is not unique, and is auto increment
    it.column(name); // Add a column to this table
    it.column(email); // Add a column to this table
}).asSQL();

// Insert statement example
users.insert( (it) {
    auto name = new Column!string("name");
    auto email = new Column!string("email");
    it[name] = "John Smith"; // Set field called name to a specific value
    it[email] = "john.smith@example.com"; // Set field called email to a specific value
}).asSQL();

// Insert or Replace statement example
users.insertOrReplace( (it) {
    auto name = new Column!string("name");
    auto email = new Column!string("email");
    it[name] = "John Smith";
    it[email] = "john.smith@example.com";
}).asSQL();

// Select query example with all columns returned
auto email = new Column!string("email");
users.select().where(email.eq("john.smith@example.com")).asSQL();

// Select query example with a specific column returned
auto name = new Column!string("name"); // The column which is returned
auto email = new Column!string("email"); // The column which is searched
users.select(name).where(email.contains("@example.com")).asSQL(); // Select name(s) from where email contains @example.com

// Count query example
users.count().asSQL(); // Count all the rows in a table
users.count().where(name.eq("john")).asSQL(); // Count specific rows where name equals John
```


## Installation
Dub Manually:
```manual
dub add fluentsqlite
```
Dub SDL:
```sdl
dependency "fluentsqlite" version="~>0.1.5"
```
Dub JSON:
```json
"fluentsqlite": "~>0.1.5"
```
