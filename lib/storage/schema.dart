class Schema {
  static const friend = """
  CREATE TABLE friends (
    docId TEXT NOT NULL,
    userId TEXT UNIQUE NOT NULL,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    belongTo TEXT NOT NULL,
    createdOn INTEGER NOT NULL,
    lastModified INTEGER NOT NULL,
    status INTEGER NOT NULL,
    createdBy TEXT NOT NULL,
    nickname TEXT NULL,
    PRIMARY KEY (docId, belongTo)
  )
                        """;

  /// [syncPoint] and [lastMessage] would be serialized as JSON string in database
  /// so they should be deserialized as JSON/Map when reading from database
  /// currently only for one-to-one chat
  static const chat = """
  CREATE TABLE chats (
    docId TEXT NOT NULL,
    members TEXT NOT NULL,
    membersHash TEXT NOT NULL,
    belongTo TEXT NOT NULL,
    cluster TEXT NOT NULL,
    createdOn INTEGER NOT NULL,
    lastModified INTEGER NOT NULL,
    syncPoint TEXT NULL,
    lastMessage TEXT NULL,
    unread INTEGER NOT NULL,
    PRIMARY KEY (docId, belongTo, membersHash)
  )
                      """;

  static const message = """
  CREATE TABLE messages (
    docId TEXT NOT NULL,
    chatId TEXT NOT NULL,
    sender TEXT NOT NULL,
    belongTo TEXT NOT NULL,
    cluster TEXT NOT NULL,
    createdOn INTEGER NOT NULL,
    lastModified INTEGER NOT NULL,
    status INTEGER NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL,
    quoteId TEXT NULL,
    PRIMARY KEY (docId, chatId, belongTo)
  )
                          """;

  static const checkPoints = """
  CREATE TABLE checkPoints (
    belongTo TEXT NOT NULL,
    id TEXT NOT NULL,
    point INTEGER NOT NULL,
    PRIMARY KEY (id, belongTo)
  )
  """;

  static const List<String> debugDrops = [
    "DROP TABLE IF EXISTS friends",
    "DROP TABLE IF EXISTS chats",
    "DROP TABLE IF EXISTS messages",
    "DROP TABLE IF EXISTS checkPoints",
  ];
}
