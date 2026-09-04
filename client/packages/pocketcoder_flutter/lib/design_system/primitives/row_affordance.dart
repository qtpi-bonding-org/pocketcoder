/// A marker on a tappable row. Unwrapped: the row is the tap target.
///
/// `navigate` and `expand` are deliberately separate members rather than a
/// single "chevron", because an arrow means *go there* and a triangle means
/// *open this*, and using one for the other is a real error rather than a
/// stylistic choice.
enum RowAffordance {
  none(''),
  navigate('→'), // arrow -- pushes another screen
  expand('▾'), // small triangle down -- reveals in place
  collapse('▴'); // small triangle up -- hides in place

  const RowAffordance(this.glyph);
  final String glyph;
}
