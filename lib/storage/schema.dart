class Schema {
  static const contact = """
  CREATE TABLE contacts (
    id TEXT PRIMARY KEY,
    inviter TEXT UNIQUE NOT NULL,
    invitee TEXT UNIQUE NOT NULL,
    createdOn INTEGER NOT NULL,
    lastModified INTEGER NOT NULL,
    status INTEGER NOT NULL
  )
                          """;

  static const chat = """
  CREATE TABLE chats (
    id TEXT PRIMARY KEY,
    members TEXT NOT NULL,
    membersHash TEXT UNIQUE NOT NULL,
    clusters TEXT NOT NULL,
    createdOn INTEGER NOT NULL,
    lastModified INTEGER NOT NULL,
    lastMessage TEXT NULL,
    unread INTEGER NOT NULL
  )
                      """;

  static const syncPoint = """
  CREATE TABLE sync_points (
    chatId TEXT PRIMARY KEY,
    msgId TEXT PRIMARY KEY,
    lastSync INTEGER NOT NULL,
    lastModified INTEGER NOT NULL
  )
                            """;

  static const message = """
  CREATE TABLE messages (
    id TEXT NOT NULL,
    chatId TEXT NOT NULL,
    sender TEXT NOT NULL,
    cluster TEXT NOT NULL,
    createdOn INTEGER NOT NULL,
    lastModified INTEGER NOT NULL,
    status INTEGER NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL,
    quoteId TEXT NULL,
    PRIMARY KEY (id, chatId, cluster)
  )
                          """;
}
