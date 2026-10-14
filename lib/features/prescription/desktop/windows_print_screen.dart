import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/errors/app_error_handler.dart';
import 'windows_print_settings.dart';

typedef WindowsPdfBuilder = Future<Uint8List> Function(PdfPageFormat format, bool bill);

class WindowsPrintScreen extends StatefulWidget {
  const WindowsPrintScreen({super.key,this.buildPdf,this.onBillMode,this.documentName='PP App',this.settingsOnly=false});
  final WindowsPdfBuilder? buildPdf;
  final Future<void> Function()? onBillMode;
  final String documentName;
  final bool settingsOnly;
  @override
  State<WindowsPrintScreen> createState() => _WindowsPrintScreenState();
}

class _WindowsPrintScreenState extends State<WindowsPrintScreen> {
  List<Printer> _printers=[];
  String _printerUrl='';
  String _paper='A4';
  bool _landscape=false, _bill=false, _loading=true, _working=false;
  String? _printerError, _pdfError;
  Uint8List? _bytes;
  int _revision=0;
  final _margins=List.generate(4,(_) => TextEditingController(text:'10'));
  final _form=GlobalKey<FormState>();

  @override
  void initState(){ super.initState(); _initialize(); }
  @override
  void dispose(){ for(final c in _margins){c.dispose();} super.dispose(); }
  WindowsPrintSettings _settings() => WindowsPrintSettings(printerUrl:_printerUrl,paper:_paper,
    landscape:_landscape,top:double.tryParse(_margins[0].text) ?? -1,
    bottom:double.tryParse(_margins[1].text) ?? -1,left:double.tryParse(_margins[2].text) ?? -1,
    right:double.tryParse(_margins[3].text) ?? -1);
  void _apply(WindowsPrintSettings s){
    _printerUrl=s.printerUrl; _paper=s.paper; _landscape=s.landscape;
    final values=[s.top,s.bottom,s.left,s.right];
    for(var i=0;i<4;i++){_margins[i].text=values[i].toString();}
  }
  void _report(String action,StackTrace stack){
    AppErrorHandler.recordUnawaited(StateError('Windows $action failed.'),stack,
      source:'WindowsPrinting',context:action);
  }
  void _message(String text){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}

  Future<void> _initialize() async {
    try { final s=await WindowsPrintSettings.load(_bill); if(!mounted)return; _apply(s); }
    catch(_,stack){_report('load settings',stack);_message('Saved settings could not be loaded. Defaults are in use.');}
    await _refreshPrinters();
    if(!mounted)return;
    setState(() => _loading=false);
    if(!widget.settingsOnly) await _generate();
  }
  Future<void> _refreshPrinters() async {
    try {
      final info=await Printing.info();
      if(!info.canListPrinters) throw UnsupportedError('Printer enumeration unavailable');
      final printers=await Printing.listPrinters();
      if(!mounted)return;
      setState(() { _printers=printers; _printerError=null;
        if(!_printers.any((p)=>p.url==_printerUrl)) _printerUrl='';
      });
    } catch(_,stack){_report('printer discovery',stack);if(mounted)setState(() => _printerError=
      'Printers could not be listed. Check Windows printer setup and Refresh. PDF export remains available.');}
  }
  Future<void> _generate() async {
    if(widget.buildPdf==null || !mounted)return;
    final s=_settings();
    if(!(_form.currentState?.validate() ?? true) || !s.valid){_message('Check margins: 0–40 mm with sufficient printable area.');return;}
    final revision=++_revision;
    setState((){_working=true;_bytes=null;_pdfError=null;});
    try{
      final bytes=await widget.buildPdf!(s.format,_bill);
      if(mounted && revision==_revision)setState(() => _bytes=bytes);
    }catch(_,stack){_report('PDF composition',stack);if(mounted)setState(() => _pdfError=
      'The PDF could not be prepared. Check the document and page settings, then retry.');}
    finally{if(mounted && revision==_revision)setState(() => _working=false);}
  }
  Future<void> _changeMode(bool bill) async {
    if(_working || _loading || bill==_bill)return;
    setState(() => _working=true);
    try{
      // Preserve existing bill creation/check flow only on explicit Bill selection.
      if(bill && !widget.settingsOnly) await widget.onBillMode?.call();
      final s=await WindowsPrintSettings.load(bill);
      if(!mounted)return;
      setState((){_bill=bill;_apply(s);_bytes=null;
        if(!_printers.any((p)=>p.url==_printerUrl))_printerUrl='';});
    }catch(_,stack){_report('change document mode',stack);_message('Document mode could not be changed. Retry.');}
    finally{if(mounted)setState(() => _working=false);}
    if(!widget.settingsOnly && mounted)await _generate();
  }
  Future<void> _openSettings() async {
    if (_working || _loading) return;
    setState(() => _working = true);
    try {
      await Navigator.push<void>(context, MaterialPageRoute(
        builder: (_) => const WindowsPrintScreen(settingsOnly: true)));
      final settings = await WindowsPrintSettings.load(_bill);
      if (!mounted) return;
      setState(() { _apply(settings); _bytes = null;
        if (!_printers.any((p) => p.url == _printerUrl)) _printerUrl = '';
      });
    } catch (_, stack) {
      _report('open settings', stack);
      _message('Printer settings could not be opened. Retry.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (mounted) await _generate();
  }
  Future<void> _saveSettings() async {
    final s=_settings();
    if(!(_form.currentState?.validate() ?? false)||!s.valid){_message('Check the paper margins.');return;}
    setState(() => _working=true);
    try{await s.save(_bill);_message('Settings saved for ${_bill ? 'bills' : 'prescriptions'}.');}
    catch(_,stack){_report('save settings',stack);_message('Settings could not be saved. Retry.');}
    finally{if(mounted)setState(() => _working=false);}
  }
  Future<void> _print({bool test=false}) async {
    if(_working)return;
    Printer? printer;
    for(final p in _printers){if(p.url==_printerUrl)printer=p;}
    if(printer==null){_message('Select an installed Windows printer first.');return;}
    final settings=_settings();
    if(!settings.valid){_message('Check the paper margins.');return;}
    if(!test && _bytes==null)return;
    setState(() => _working=true);
    try{
      final info=await Printing.info();
      if(!info.canPrint)throw UnsupportedError('Printing unavailable');
      if(!info.directPrint)throw UnsupportedError('Direct printing unavailable');
      Uint8List bytes;
      if(test){
        final doc=pw.Document();
        doc.addPage(pw.Page(pageFormat:settings.format,build:(_) => pw.Column(
          crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
            pw.Text('PP App - Printer test',style:const pw.TextStyle(fontSize:20)),
            pw.SizedBox(height:15),pw.Text('Paper: ${settings.paper} / ${settings.landscape ? 'Landscape' : 'Portrait'}'),
            pw.Text('Margins mm: ${settings.top}, ${settings.bottom}, ${settings.left}, ${settings.right}'),
            pw.SizedBox(height:20),pw.Container(height:80,width:180,decoration:pw.BoxDecoration(border:pw.Border.all())),
            pw.Text('No patient data is included in this test.'),
          ])));
        bytes=await doc.save();
      }else{bytes=_bytes!;}
      final submitted=await Printing.directPrintPdf(printer:printer,
        onLayout:(_) async => bytes,format:settings.format,dynamicLayout:false,
        usePrinterSettings:false,name:test ? 'PP App printer test' : '${_bill ? 'Bill' : 'Prescription'} ${widget.documentName}');
      _message(submitted ? 'Print job submitted. Check the Windows queue and printer.' : 'Print job was cancelled or not submitted.');
    }catch(_,stack){_report('print submission',stack);_message('Print submission failed. Check the printer/driver and Windows queue before retrying.');}
    finally{if(mounted)setState(() => _working=false);}
  }
  Future<void> _export() async {
    if(_working || _bytes==null)return;
    setState(() => _working=true);
    try{
      final safe=widget.documentName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'),'_');
      final location=await getSaveLocation(suggestedName:'${_bill ? 'bill' : 'prescription'}_$safe.pdf',
        acceptedTypeGroups:[const XTypeGroup(label:'PDF',extensions:['pdf'])]);
      if(location==null)return;
      var path=location.path;
      if(!path.toLowerCase().endsWith('.pdf'))path='$path.pdf';
      if (await File(path).exists()) {
        if (!mounted) return;
        final overwrite = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
          title: const Text('Replace existing PDF?'),
          content: const Text('A file already exists at this location.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace'))]));
        if (overwrite != true) return;
      }
      await XFile.fromData(_bytes!,mimeType:'application/pdf').saveTo(path);
      _message('PDF saved.');
    }catch(_,stack){_report('PDF export',stack);_message('PDF could not be saved. Check the destination and retry.');}
    finally{if(mounted)setState(() => _working=false);}
  }

  Widget _controls(){
    final busy=_working||_loading;
    return Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      DropdownButtonFormField<bool>(value:_bill,decoration:const InputDecoration(labelText:'Document defaults'),
        items:const [DropdownMenuItem(value:false,child:Text('Prescription')),DropdownMenuItem(value:true,child:Text('Bill'))],
        onChanged:busy ? null : (v){if(v!=null)_changeMode(v);}),
      const SizedBox(height:16),
      DropdownButtonFormField<String>(value:_printerUrl,isExpanded:true,
        decoration:const InputDecoration(labelText:'Windows printer'),
        items:[const DropdownMenuItem(value:'',child:Text('Select printer')),
          for(final p in _printers)DropdownMenuItem(value:p.url,child:Text(p.name,maxLines:1,overflow:TextOverflow.ellipsis))],
        onChanged:busy ? null : (v)=>setState(() => _printerUrl=v ?? '')),
      if(_printerError!=null)Text(_printerError!,style:const TextStyle(color:Colors.red)),
      if(_printers.isEmpty && _printerError==null)const Text('No installed printers found. You can still save a PDF.'),
      TextButton.icon(onPressed:busy ? null : () async {
        setState(() => _working=true);await _refreshPrinters();if(mounted)setState(() => _working=false);
      },icon:const Icon(Icons.refresh),label:const Text('Refresh printers')),
      DropdownButtonFormField<String>(value:_paper,decoration:const InputDecoration(labelText:'Paper size'),
        items:const [DropdownMenuItem(value:'A4',child:Text('A4')),DropdownMenuItem(value:'A5',child:Text('A5'))],
        onChanged:busy ? null : (v){setState((){_paper=v ?? 'A4';_bytes=null;});}),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Landscape'),value:_landscape,
        onChanged:busy ? null : (v)=>setState((){_landscape=v;_bytes=null;})),
      const Text('Margins (mm)',style:TextStyle(fontWeight:FontWeight.bold)),
      for(var i=0;i<4;i++) Padding(padding:const EdgeInsets.only(top:10),child:TextFormField(
        controller:_margins[i],enabled:!busy,keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:InputDecoration(labelText:['Top','Bottom','Left','Right'][i]),
        onChanged:(_)=>setState(() => _bytes=null),
        validator:(value){final n=double.tryParse(value ?? '');return n==null||!n.isFinite||n<0||n>40 ? 'Enter 0–40 mm.' : null;})),
      const SizedBox(height:16),
      if(!widget.settingsOnly)FilledButton.icon(onPressed:busy ? null : _generate,
        icon:const Icon(Icons.preview),label:const Text('Apply to preview')),
      OutlinedButton(onPressed:busy ? null : _saveSettings,child:const Text('Save defaults')),
      OutlinedButton(onPressed:busy ? null : () => _print(test:true),child:const Text('Test print')),
      TextButton(onPressed:busy ? null : () {setState((){_apply(const WindowsPrintSettings());_bytes=null;});},child:const Text('Reset defaults')),
      const Text('Windows printer driver must already be installed. A4/A5 only; thermal paper support is a separate step.',style:TextStyle(fontSize:12,color:Colors.blueGrey)),
    ]));
  }
  Widget _preview(){
    final bytes = _bytes;
    if(bytes!=null)return PdfPreview(key:ValueKey(_revision),build:(_) async => bytes,
      initialPageFormat:_settings().format,canChangeOrientation:false,canChangePageFormat:false,
      canDebug:false,allowPrinting:false,allowSharing:false,useActions:false,
      onError:(_,error)=>const Center(child:Text('Preview rendering failed. Try Apply to preview again.')));
    return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(_pdfError ??
      (_working ? 'Preparing PDF…' : 'Apply page settings to prepare the preview.'),textAlign:TextAlign.center)));
  }
  @override
  Widget build(BuildContext context){
    final busy=_loading||_working;
    return PopScope(canPop:!_working,child:Scaffold(
      backgroundColor:const Color(0xFFF3F7F7),
      appBar:AppBar(title:Text(widget.settingsOnly ? 'Printer Settings' : 'Print Preview — ${widget.documentName}'),
        actions:[if(!widget.settingsOnly)...[
          IconButton(tooltip:'Printer Settings',onPressed:busy ? null : _openSettings,icon:const Icon(Icons.settings)),
          TextButton.icon(onPressed:busy||_bytes==null ? null : _export,icon:const Icon(Icons.picture_as_pdf),label:const Text('Save PDF')),
          TextButton.icon(onPressed:busy||_bytes==null ? null : _print,icon:const Icon(Icons.print),label:const Text('Print')),
        ]]),
      body:_loading ? const Center(child:CircularProgressIndicator()) : Column(children:[
        if(_working)const LinearProgressIndicator(),
        Expanded(child:LayoutBuilder(builder:(context,c){
          final controls=SingleChildScrollView(padding:const EdgeInsets.all(22),child:_controls());
          if(widget.settingsOnly)return Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:620),child:controls));
          if(c.maxWidth<760)return Column(children:[SizedBox(height:c.maxHeight*.45,child:controls),Expanded(child:_preview())]);
          return Row(children:[SizedBox(width:300,child:controls),const VerticalDivider(width:1),Expanded(child:_preview())]);
        })),
      ])));
  }
}
