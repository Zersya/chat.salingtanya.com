class Chat {
  final String content;
  final String groupId;
  final int createdAt;
  final List<String> read;
  final List<String> write;
  final String id;
  final String collection;

  Chat({
    required this.content,
    required this.groupId,
    required this.createdAt,
    required this.read,
    required this.write,
    required this.id,
    required this.collection,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      content: json['content'] as String,
      groupId: json['group_id'] as String,
      createdAt: json['created_at'] as int,
      read: (json['\$read'] as List).map((e) => e as String).toList(),
      write: (json['\$write'] as List).map((e) => e as String).toList(),
      id: json['\$id'] as String,
      collection: json['\$collection'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['content'] = content;
    data['group_id'] = groupId;
    data['created_at'] = createdAt;
    data['\$read'] = read;
    data['\$write'] = write;
    data['\$id'] = id;
    data['\$collection'] = collection;
    return data;
  }
}
