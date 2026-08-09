import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key, required this.modes, required this.onSelectMode});
  final Map<String, dynamic>? modes;
  final ValueChanged<String> onSelectMode;
  @override Widget build(BuildContext context) {
    final available=(modes?['availableModes'] as List?)?.whereType<Map>().map(Map<String,dynamic>.from).toList() ?? const <Map<String,dynamic>>[];
    if(available.isEmpty) return const SizedBox.shrink();
    final current=modes?['currentModeId'] as String?; final colors=context.colorScheme;
    return Container(padding:EdgeInsets.symmetric(horizontal:AppSizes.space*2,vertical:AppSizes.space*.5), decoration:BoxDecoration(border:Border(top:BorderSide(color:colors.onSurface.withValues(alpha:.1),width:AppSizes.borderWidth))), child:Row(children:[Text('MODE:',style:TextStyle(color:colors.onSurface.withValues(alpha:.5),fontFamily:AppFonts.bodyFamily,fontSize:AppSizes.fontTiny,fontWeight:AppFonts.heavy,letterSpacing:2)),HSpace.x1,Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:available.map((m){final id=m['id'] as String?;final name=(m['name'] as String?)??id??'';return Padding(padding:EdgeInsets.only(right:AppSizes.space),child:_ModeChip(label:name.toUpperCase(),isSelected:id!=null&&id==current,onTap:id==null?null:()=>onSelectMode(id)));}).toList())))]));
  }
}
class _ModeChip extends StatelessWidget { const _ModeChip({required this.label,required this.isSelected,required this.onTap}); final String label; final bool isSelected; final VoidCallback? onTap; @override Widget build(BuildContext context){final c=context.colorScheme;return GestureDetector(onTap:onTap,child:Container(padding:EdgeInsets.symmetric(horizontal:AppSizes.space*1.5,vertical:AppSizes.space*.5),decoration:BoxDecoration(color:isSelected?c.primary.withValues(alpha:.15):Colors.transparent,border:Border.all(color:isSelected?c.primary:c.onSurface.withValues(alpha:.3),width:AppSizes.borderWidth)),child:Text(label,style:TextStyle(color:isSelected?c.primary:c.onSurface,fontFamily:AppFonts.bodyFamily,fontSize:AppSizes.fontMini,fontWeight:AppFonts.heavy,letterSpacing:1))));}}
