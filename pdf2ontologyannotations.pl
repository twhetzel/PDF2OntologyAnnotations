 #!/usr/bin perl

##############################################
# Usage: perl pdf2ontologyannotations.pl input_file 
#
# Description: Take in a list of PDF files, extract XML
# using the PDFX tool (http://pdfx.cs.man.ac.uk/) and then send
# to the NCBO Annotator (http://bioportal.bioontology.org/annotator) 
# to get the ontology annotations
# 
#
# Author: Trish Whetzel
# Date: Thu Sep  6 10:54:34 JST 2012
##############################################

use LWP::UserAgent;
use XML::LibXML;
use URI::Escape;
use strict;
use warnings;

$|=1;

# Declare globals variables
my (@files, @text);
my $file_dir = $ARGV[0];

my $API_KEY = '24e050ca-54e0-11e0-9d7b-005056aa3316';  # Create BioPortal account ( http://bioportal.bioontology.org/accounts/new ) to get your API key 
my $AnnotatorURL = 'http://rest.bioontology.org/obs/annotator'; 

# Subroutines 
get_pdf_files();
  #print "F: @files\n";
submit_to_pdfx(\@files);
get_xml_files();


####################################
# Get list of files in directory
###################################
sub get_pdf_files {
	#my $dir = '/Users/whetzel/Documents/workspace/PDF2OntologyAnnotations';
	#my $dir = '/Users/whetzel/Documents/Stanford/Outreach/Conferences/Biohackathon-2012/ENCODE-2012/';
	my $dir = $file_dir;
	print STDERR "DIR: $dir\n";

    opendir(DIR, $dir) or die $!;

    while (my $file = readdir(DIR)) {
        # Use a regular expression to ignore files beginning with a period
        next unless ($file =~ m/\.pdf$/);

	print "$file\n";
	push (@files, $file);
    
    }
    
    return (@files);
    closedir(DIR);
    exit 0;
}


####################################
# Submit pdf files to PDFX tool
####################################
sub submit_to_pdfx {
	my @filenames = @{(shift)}; 
	 foreach my $pdf_file (@filenames) {
		# send PDF to PDFX tool
		#curl --data-binary "$pdf_file" -H "Content-Type: application/pdf" -L "http://pdfx.cs.man.ac.uk" > ${temp}x.xml; 
	 	system "curl --data-binary @\"$file_dir$pdf_file\" -H \"Content-Type: application/pdf\" -L \"http://pdfx.cs.man.ac.uk\" > ${pdf_file}.xml"; 
	 	print STDERR "Files from from $file_dir$pdf_file\n";
	 }
	 print "Input filenames: @filenames\n";
}


################################
# Process DOCO XML
################################
sub get_xml_files {
	#my $dir = '/Users/whetzel/Documents/workspace/PDF2OntologyAnnotations';
	#my $dir = '/Users/whetzel/Documents/Stanford/Outreach/Conferences/Biohackathon-2012/ENCODE-2012';
	my $dir = $file_dir;
	my @text_to_annotate;

    opendir(DIR, $dir) or die $!;

    while (my $file = readdir(DIR)) {
        # Use a regular expression to ignore files beginning with a period
        next unless ($file =~ m/\.xml$/);

	#print "XML-PDF FILES: $file\n";
	# parse DOCO XML
    parse_doco_xml($file);
    }
    closedir(DIR);
    exit 0;
}


########################
# Parse DOCO XML
########################
sub parse_doco_xml {
	my $filename = shift;
	my @annotation_text;
	#print "FILE TO PARSE: $filename\n";
	
	my $parser = XML::LibXML->new();
  	my $doc    = $parser->parse_file($filename);

  foreach my $element ($doc->findnodes('/pdfx')) {
    #my($job-id) = $element->findnodes('./meta/job');
	my ($title) = $element->findnodes('//article-title');
    #print "TITLE: ", $title->to_literal, "\n";
    my $title_text = $title->to_literal;
    push (@annotation_text, $title_text."\ ");
       
    my ($abstract) = $element->findnodes('//abstract');
    if ($abstract) {
    	#print "ABSTRACT: ", $abstract->to_literal, "\n";
    	my $abstract_text = $abstract->to_literal;
    	push (@annotation_text, $abstract_text."\ ");
    }
    else {
    	#print "ABSTRACT: NO ABSTRACT FOUND\n";
    }
   
    
    my ($body) = $element->findnodes('//body//region');
    #print "BODY REGION:\n", $body->to_literal, "\n"; 
    my $body_text = $body->to_literal;
    push (@annotation_text, $body_text); 
  }
	print "-----\n";	

	#concatenate text to send to annotator
	#print "\n**TEXT TO ANNOTATE:\n", @annotation_text, "\n**END TEXT TO ANNOTATE\n";
	my $text = join(' ', @annotation_text);
	#return @annotation_text;
	submit_to_annotator($text);
}


##############################
# Submit text to annotator
##############################
sub submit_to_annotator {
	my $text_to_annotate = shift;
	my $text = uri_escape_utf8($text_to_annotate);
	print "TEXT TO SEND TO NCBO ANNOTATOR: $text\n";
	
# create a user agent
my $ua = new LWP::UserAgent;
$ua->agent('Annotator Client Example - Perl');

# create a parse to handle the output 
my $parser = XML::LibXML->new();

# create a POST request
my $req = new HTTP::Request POST => "$AnnotatorURL";
   $req->content_type('application/x-www-form-urlencoded');

my $format = "xml"; #xml, tabDelimited, text

# Set parameters
# Check docs for extra parameters
$req->content("longestOnly=false&"
			 ."wholeWordOnly=true&"
			 ."withContext=true&"
			 ."filterNumber=true&"
			 ."stopWords=&"
			 ."withDefaultStopWords=false&"
			 ."isStopWordsCaseSenstive=false&"
			 ."minTermSize=3&"   
			 ."scored=true&" 
			 ."withSynonyms=true&" 
			 ."ontologiesToExpand=1032&"   
			 ."ontologiesToKeepInResult=1032&" 
			 ."isVirtualOntologyId=true&"  #Suggest to set to true and use ontology virtual id 
			 ."semanticTypes=&" #T018,T023,T024,T025,T030&" 
			 ."levelMax=0&"
			 ."mappingTypes=Automatic&"  # null=do not expand mappings, Automatic, Manual 
			 ."textToAnnotate=$text&"
			 ."format=$format&"  #);  #Possible values: xml, tabDelimited, text 
			 ."apikey=$API_KEY"); #Change to include your API Key  

# send request and get response.
my $res = $ua->request($req);

# Check the outcome of the response
if ($res->is_success) {
	my $time = localtime();
    print STDERR "Call successful at $time\n";
  
  	# print $res->decoded_content;  # this line prints out unparsed response 
    
    # Parse the response 
    print "Format: $format\n";
    if ($format eq "xml") {
 		my ($M_ConceptREF, $M_PhraseREF) = parse_annotator_response($res, $parser);

	# Print something for the user
    print scalar (keys %{$M_ConceptREF}), " concepts found\n";
    foreach my $c (keys %{$M_ConceptREF}){
    	print STDERR $c,"\t", $$M_ConceptREF{$c},"\t","matched\t", $$M_PhraseREF{$c},"\n";
    }    
  }
}
else {
	my $time = localtime();
    #print $res->status_line, " at $time\n";
	print $res->content, " at $time\n";
}


###################
# parse response
###################
sub parse_annotator_response {
	my ($res, $parser) = @_;
    my $dom = $parser->parse_string($res->decoded_content);
	my $root = $dom->getDocumentElement();
	my %MatchedConcepts;
	my %MatchedPhrase;
		
	# parse results from "CONCEPT" 	
	my $results = $root->findnodes('/success/data/annotatorResultBean/annotations/annotationBean/concept');
	foreach my $c_node ($results->get_nodelist){
                # Sample XPATH to extract concept info if needed
		#print "ID = ", $c_node->findvalue('localConceptId'),"\n";
		print "URI = ", $c_node->findvalue('fullId'),"\n";
		print "Name = ", $c_node->findvalue('preferredName'),"\n";
		print "Synonyms = ", $c_node->findvalue('synonyms/string'),"\n";
		#print "Type = ", $c_node->findvalue('./semanticTypes/semanticTypeBean[1]/localSemanticTypeId'),"\n";
		#print "Type name = ", $c_node->findvalue('./semanticTypes/semanticTypeBean[1]/name'),"\n\n";
		
		$MatchedConcepts{$c_node->findvalue('localConceptId')} = $c_node->findvalue('preferredName');
		#$MatchedConcepts{$c_node->findvalue('fullId')} = $c_node->findvalue('preferredName');
	}
		
	# parse results from "CONTEXT" 		
	$results = $root->findnodes('/success/data/annotatorResultBean/annotations/annotationBean/context');
	foreach my $c_node ($results->get_nodelist){
                # Sample XPATH to extract concept info if needed
		#print "ID = ", $c_node->findvalue('./term/localConceptId'),"\n";
		print "URI = ", $c_node->findvalue('./term/fullId'),"\n";
		print "Match = ", $c_node->findvalue('./term/name'),"\n";
		print "From = ", $c_node->findvalue('from'),"\n";
		print "To = ", $c_node->findvalue('to'),"\n";
			
		$MatchedPhrase{$c_node->findvalue('./term/localConceptId')} = $c_node->findvalue('./term/name');
		#$MatchedPhrase{$c_node->findvalue('./fullId')} = $c_node->findvalue('./term/name');
	}		
	return (\%MatchedConcepts, \%MatchedPhrase);
}
}



