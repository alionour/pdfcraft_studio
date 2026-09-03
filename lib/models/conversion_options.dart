class ConversionOptions {
  final int dpi;
  final String format; // 'png' or 'jpeg'
  final String pageRange; // e.g. 'all', '1-5', '2,4'
  final bool transparent;
  final String colorMode; // 'color' or 'grayscale'
  final String namingPattern; // e.g. '{pdf_name}_page_{page}'
  final Set<int>? selectedPages; // Visual page selection if non-null

  const ConversionOptions({
    this.dpi = 150,
    this.format = 'png',
    this.pageRange = 'all',
    this.transparent = false,
    this.colorMode = 'color',
    this.namingPattern = '{pdf_name}_page_{page}',
    this.selectedPages,
  });

  ConversionOptions copyWith({
    int? dpi,
    String? format,
    String? pageRange,
    bool? transparent,
    String? colorMode,
    String? namingPattern,
    Set<int>? selectedPages,
  }) {
    return ConversionOptions(
      dpi: dpi ?? this.dpi,
      format: format ?? this.format,
      pageRange: pageRange ?? this.pageRange,
      transparent: transparent ?? this.transparent,
      colorMode: colorMode ?? this.colorMode,
      namingPattern: namingPattern ?? this.namingPattern,
      selectedPages: selectedPages ?? this.selectedPages,
    );
  }
}
