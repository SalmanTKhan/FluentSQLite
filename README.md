# FluentSQLite
 An implementation of SQLite Query Builder in D Lang, originally ported from fluks.

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
Hope to have it on dub.
```sdl
dependency "taskdesigns:sqlite" version="~>0.0.1"
```
