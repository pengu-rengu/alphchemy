class GeneratorData {
  final Map<String, dynamic> generator;
  final Map<String, dynamic> paramSpace;

  const GeneratorData({required this.generator, required this.paramSpace});

  factory GeneratorData.fromJson(Map<String, dynamic> json) {
    final generator = json["generator"] as Map<String, dynamic>? ?? {};
    final paramSpace = json["param_space"] as Map<String, dynamic>? ?? {};
    return GeneratorData(generator: generator, paramSpace: paramSpace);
  }
  
  factory GeneratorData.blank(String title) {
    return GeneratorData(
      generator: {"title": title},
      paramSpace: {"search_space": <String, dynamic>{}}
    );
  }

  Map<String, dynamic> toJson() {
    return {"generator": generator, "param_space": paramSpace};
  }
}
