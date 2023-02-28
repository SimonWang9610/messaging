enum MessageType {
  /// the [BaseMessage]'s body would be [text]
  text("text"),

  /// the [BaseMessage]'s body would be [mediaUrl]
  image("image"),
  video("video"),
  audio("audio");

  final String value;
  const MessageType(this.value);

  static MessageType fromString(String value) {
    switch (value) {
      case "text":
        return text;
      case "image":
        return image;
      case "video":
        return video;
      case "audio":
        return audio;
      default:
        throw UnsupportedError("mapping $value to [MessageType] not supported");
    }
  }
}
