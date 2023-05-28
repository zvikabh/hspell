#!/usr/bin/perl -w
#
# Copyright (C) 2000-2015 Nadav Har'El, Dan Kenigsberg
#
use Carp;
use FileHandle;

my $detailed_output=0;
my $detail_prefix;

# This arrays will be useful later to convert ordinary letters into final,
# and vice-versa.
my %fin = ('�'=>'�', '�'=>'�', '�'=>'�', '�'=>'�', '�'=>'�');
my %nif = ('�'=>'�', '�'=>'�', '�'=>'�', '�'=>'�', '�'=>'�');

sub outword {
  my $word = shift;
  my $details = shift;

  # "*" sign used to signify non-existant word that should not be output.
  # It will allow us to more-easily drop words without huge if()s.
  return if $word =~ m/^\*/;

  # change otiot-sofiot in the middle of the word
  # (the silly a-z was added for our special "y" and "w" marks).
  # (the ('?) and $2 are for �������', �������'��)
  $word =~ s/([�����])('?)(?=[�-�a-z])/$nif{$1}$2/go;

  # change special consonant marks into the proper Hebrew letters, using
  # proper ktiv male rules.

  # Note that the order of these conversion is important. Since they have
  # the potential of changing so many words, it is highly recommended to
  # diff the output files before and after the change, to see that no
  # unexpected words got changed.

  # The vowel markers 'a' and 'e' do nothing except to a yud (chirik male) -
  # which turns it into a consonant yud; For example your(feminine) �� is
  # ���� (tsere in the yud, so it's a consonant and doubled) and
  # your(masculine) �� is ��� (yud is chirik male, and not doubled)
  $word =~ s/�[ea]/y/go;
  $word =~ s/[ea]//go;

  # The vowel 'i' is a chirik chaser - it should be followed by a yud if
  # necessary. We do nothing with it currently - it's only useful for words
  # like ���i� where we want to make sure that wolig.pl does not think this
  # is the normal patach-aleph-yud (with no niqqud under the aleph) case as
  # in ����.
  # The first rule here is useful for transformation from ��� to �����, via
  # ��� adj-inword> ��i� feminine> ��i�a� outword> ��iy� outword> �����
  $word =~ s/iy/��/go;  # useful in stuff like ��i� - �����
  $word =~ s/i//go;

  # Y is the same as y, except it is not translated to a double-yud (but rather
  # to a single yud) when it is the last letter of the word. It's used in words
  # like ���� in which the original form of the word has a chirik male, but in
  # all the inflections the yud from the chirik becomes a fully-fleged
  # consonant. We do not need a similar trick for vav (w), because the
  # Academia's rules do not do anything to a vav at the end of the word,
  # contrary to what happens to a yud.
  # I'm not sure this trick is "kosher" (based on the language), but it does
  # work...
  $word =~ s/Y($|(?=-))/�/go;  # Y's at the end of the word
  $word =~ s/Y/y/go;       # the rest of the Y's are converted to y's

  # The first conversion below implements the akademia's rule that a chirik
  # before a y� should not be written with a �. So we convert �y� into ��.
  # IDEA: to be more certain that the first � functions as a chirik, it would
  # have been better to use the i character: in addition to the �� -> y� rule
  # we have in the beginning of processing a word, we should do ��� -> iy�.
  # Then here the rule would convert iy�, not �y�. [but everything is working
  # well even without this idea]
  $word =~ s/�y�/��/go;
  $word =~ s/(?<=[^��y])y(?=[^��y�]|$)/��/go;
  $word =~ s/y/�/go;                      # otherwise, just one yud.

  # The first conversion below of �w to � has an interesting story. In the
  # original Hebrew, the consonant � sounded like the English w or Arabic
  # waw. An "u" sound (a kubuts, which we mark by �) followed by this w
  # sound sounded like a long "u", which was later written with a shuruk,
  # i.e., one vav. This conversion is very useful for understanding how the
  # word ��� is inflected (see explanation in wolig.dat).
  $word =~ s/�w/�/go;
  $word =~ s/(?<=[^�w])w(?=[^�w-])/��/go;  # if vav needs to be doubled, do it
  $word =~ s/w/�/go;                       # otherwise, just one vav.

  # A consonant � (h) is always output as a �. The only reason we are
  # interested in which � is consonant is to allow the rules earlier to double
  # yud next to a consonant � (i.e.. h), but not next to a em-kria �.
  # For example, compare ���� (lion) and ����� (her lion).
  $word =~ s/h/�/go;

  if($detailed_output && defined($details)){
    $word =~ s/-$//;  # smichut is already known by the details...
    $word .= " ".$detail_prefix.$details;
  }
  print $word."\n";
}

sub inword {
  # For some combinations of ���� at the end or beginning of a word, we can
  # immediately guess that these must be consonants (and not vowels) and make
  # use of that knowledge by changing the Hebrew letters into the markers
  # "w", "y" we use for consonants � and � respectively.
  #
  # This function takes a word as inputted from wolig.dat, presumably written
  # in ktiv male, and makes a few predictions, such as that a vav in the
  # beginning of the word must be a consonant. Predictions that appear here
  # must have two traits:
  # 1. They must be useful for the correct inflection of some word.
  #    For example, realising that the �� at the end of ����� is a consonant
  #    help us later avoid the false inflection ����� and instead generate
  #    the correct ����.
  # 2. They must be correct in 100% of the cases. For example, a rule saying
  #    that every appearance of �� in the input is a consonant (w) is wrong,
  #    because of words like �����.
  #    However, the rules only have to "appear" correct (for all the actual
  #    words in wolig.dat), not necessarily be linguisticly correct. For
  #    example, we'll see below a rule that a � at the end of a word is a
  #    consonant (w). This is indeed true for most nouns (��, ������), but not
  #    for ���. However, all of ���'s inflections have a consonant vav, and in
  #    the word itself we don't really care about mislabeling it "consonant"
  #    because a vav at the end of the word isn't doubled anyway under the
  #    Academia's rules.
  #
  # Actually the second rule can be relaxed a bit if we provide alternative
  # ways to input a certain construct. For example, if "u" could signify a
  # vowel vav in the input, then we wouldn't really care if in a few rare cases
  # we wrongly decide a certain vav to be consonant: the user could override
  # this decision by putting a "u" explicitly, instead of the vav, in the
  # input file.

  my $word = shift;
  if(substr($word,0,1) eq "�"){
    # A word cannot start with a shuruk or kubuts!
    substr($word,0,1)="w";
  }
  if(substr($word,-4,4) eq "����"){
    # A word like �����, ������, �������. I can't imagine any base noun (or
    # adjective) for which such a double-vav isn't a consonant but rather
    # a vav and shuruk.
    substr($word,-4,2)="w";
  }
  if(substr($word,-1,1) eq "�"){
    # This vav is a consonant (see comment above about why the few exceptions
    # that do exist don't bother us).
    substr($word,-1,1)="w";
  } elsif(substr($word,-3,3) eq "���"){
    # If the word ends with ���, the user wrote in ktiv male and intended
    # a consonant vav. Replace the �� by the character "w", which will be
    # doubled if necessary (for ktiv male) by outword. This change actually
    # makes a difference for the ����_� with �� cases: for example, the
    # word ����� has a plural ����� and his-possesive ����. Without this
    # change, we get the incorrect possesive ����� and plural ������.
    # Similarly it is needed for the adjective �����'s correct feminine plural.
    substr($word,-3,2)="w";
  } elsif(substr($word,-2,2) eq "��"){
    substr($word,-2,1)="y";
    # TODO: maybe convert ��� (in ktiv male, e.g., ��������) into iy�.
    # see outword above on a discussion about that. But everything also
    # works without this change.
  }
  return $word;
}

#############################################################################

my ($fh,$word,$optstring,%opts);

my $infile;
if($#ARGV < 0){
  $infile="wolig.dat";
} else {
  if($ARGV[0] eq "-d"){
    $detailed_output=!$detailed_output;
    shift @ARGV;
  }
  $infile=$ARGV[0];
}

$fh = new FileHandle $infile, "r"
  or croak "Couldn't open data file $infile for reading";
while(<$fh>){
  print if /^#\*/;        # print these comments.
  chomp;
  s/#.*$//o;              # comments start with '#'.
  next if /^[ 	]*$/o;    # ignore blank lines.
  ($word,$optstring)=split;
  die "Type of word '".$word."' was not specified." if !defined($optstring);
  undef %opts;
  my $val;
  foreach $opt (split /,/o, $optstring){
    ($opt, $val) = (split /=/o, $opt);
    $val = 1 unless defined $val;
    $opts{$opt}=$val;
  }
  if($opts{"�"}){
    ############################# noun ######################################
    # Shortcuts
    if($opts{"���_�����"}){
      $opts{"����"}=1; $opts{"���_�����_����"}=1;
    }
    if($opts{"���_�������"}){
      $opts{"���_������_����"}=1; $opts{"���_������_����"}=1;
    }
    # note that the noun may have several plural forms (see, for example,
    # ���). When one of the plural forms isn't explicitly specified, wolig
    # tries to guess, based on simplistic heuristics that work for the majority
    # of the nouns (84% of them, at one time I counted).
    my $plural_none = $opts{"����"} || substr($word,-3,3) eq "���";
    my $plural_bizarre = exists($opts{"����"});
    my $plural_implicit = !($opts{"��"} || $opts{"��"} || $opts{"���"}
                           || $opts{"���"} || $opts{"���"} || $plural_none
                           || $plural_bizarre);
    my $plural_iot = $opts{"���"} ||
      ($plural_implicit && (substr($word,-2,2) eq "��"));
    my $plural_xot = $opts{"���"};
    my $plural_ot = $opts{"��"} ||
      ($plural_implicit && !$plural_iot && (substr($word,-1,1) eq "�" || substr($word,-1,1) eq "�" ));
    my $plural_im = $opts{"��"} || ($plural_implicit && !$plural_ot && !$plural_iot);
    my $plural_iim = $opts{"���"};

    # Find gender for detailed output. This has nothing to do with word
    # inflection, it's just an added value of wolig.pl...
    if($detailed_output){
      my $gender;
      if($opts{"���"}){
        if($opts{"����"}){
          $gender="�,�";
        } else {
          $gender="�";
        }
      } elsif($opts{"����"}){
        $gender="�"
      } elsif($opts{"����_�"}){
        $gender="�";
      } elsif((substr($word,-1,1) eq "�") && !$opts{"���_�"}){
        $gender="�";
      } elsif(substr($word,-1,1) eq "�" && !$opts{"��"}){
        $gender="�";
      } else {
        $gender="�";
      }
      $detail_prefix="$gender,";
    }

    # preprocess the word the user has given, converting certain ktiv male
    # constructs into markers (w, y) that we can better work with later (see
    # comments in inword() about what it does).
    $word=inword($word);

    # related singular noun forms
    if(exists $opts{"����"}){
      outword $opts{"����"}, "�,����";  # explicit override of the nifrad
    } elsif(!$opts{"���_����"}){
      outword $word, "�,����"; # the singular noun itself
    }
    if($opts{"���_�"}){
      # in words like ������ and ������ the first yud (coming from chirik
      # or tsere in ktiv male) is lost in all but the base word
      $word =~ s/�//o;
    }
    my $smichut=$word;
    if($opts{"���_����"} || $opts{"���_�����_����"}){
      # We mark the singular words with "*", telling outword to drop them.
      # This makes the code look cleaner than a huge if statement around all
      # the singular code. Maybe in the future we should move the singular
      # inflection code to a seperate function, if() only around that, and
      # stop all that "*" nonsense.
      $smichut="*".$smichut;
    }
    #my $smichut_orig=$smichut;
    if($opts{"�����_��"}){
      # special case:
      # ��, ��, ��, �� include an extra yod in the smichut. Note that in the
      # first person singular possessive, we should drop that extra yod.
      # For a "im" plural, it turns out to be the same inflections as the
      # plural - but this is not the case with a "ot" plural.
      # Interestingly, the yud in these inflections is always a chirik
      # male - it is never consonantal (never has a vowel on it).
      if(substr($smichut,-1,1) eq "�"){
        # Remove the �. Basically, only one word fits this case: ��
        $smichut=substr($smichut,0,-1);
        # And add the extra third-person masuline possesive (just like the
        # ����_� case, but we don't bother to check for the ����_� flag here).
        outword $smichut."���", "�,����,��/���";
      }
      outword $smichut."�-",  "�,����,������"; # smichut
      outword $smichut."�",   "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."���", "�,����,��/�����";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."��",  "�,����,��/��";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."���", "�,����,��/��";
      outword $smichut."���", "�,����,��/��";
    } else {
      if(!$opts{"����_�"}){ # replace final � by �, unless ����_� option
        if(substr($smichut,-1,1) eq "�" && !$opts{"����_�"}){
          substr($smichut,-1,1)="�";
        }
      }
      if(exists($opts{"����"})){
        outword $opts{"����"}."-", "�,����,������";
      } else {
        outword $smichut."-", "�,����,������"; # smichut
      }
      if($opts{"�����_��"}){
        # academia's ktiv male rules indicate that the inflections of ��
        # (at least the plural is explicitly mentioned...) should get an
        # extra yud - to make it easy to distinguish from the number �����.
        substr($smichut,0,-1)=substr($smichut,0,-1).'�';
        substr($word,0,-1)=substr($word,0,-1).'�';
      }
      if(substr($word,-2,2) eq "��" && length($word)>2){
        # in words ending with patach and then the imot kria aleph yud,
        # such as ���� and ����, all the inflections (beside the base word
        # and the smichut) are as if the yud wasn't there.
        # Note that words ending with �� but not patach, like �� and ����,
        # should not get this treatment, so there should be an option to turn
        # it off.
        substr($word,-1,1)="";
        substr($smichut,-1,1)="";
      }
      # Note that the extra vowel markers, 'a' and 'e' are added for mele'im
      # ending with yud (e.g., ��) - this vowel attaches to the yud and makes
      # the yud a consonant. This phenomenon is handled in outword.
      my $no_ah=0;
      if($opts{"����_�"}){
        # the � is dropped from the singular inflections, except one alternate
        # inflection like ����� (the long form of ����):
        # (there's another femenine inflection, ���� with kamats on the he,
        # but this is spelled the same (as ���� with mapik) without niqqud so
        # we don't need to print it again).
        if(substr($smichut,-1,1) eq "�"){
          $smichut=substr($smichut,0,-1);
        }
	unless ($opts{"���_������_����"}){
        	outword $smichut."eh�", "�,����,��/���";
	}
        # TODO: maybe add the "eha" inflection? But it won't generate anything
        # different from the ah below...
        #outword $smichut."eha" unless $no_ah;
      }
      unless ($opts{"���_������_����"}){
      outword $smichut."�",   "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."e��", "�,����,��/�����";
      outword $smichut."�",   "�,����,��/���";
      outword $smichut."e�",  "�,����,��/��";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."�",   "�,����,��/���";
      outword $smichut."ah",  "�,����,��/���";
      outword $smichut."a�",  "�,����,��/��";
      outword $smichut."a�",  "�,����,��/��";
      }
    }
    # related plural noun forms
    # note: don't combine the $plural_.. ifs, nor use elsif, because some
    # nouns have more than one plural forms.
    if($plural_im){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�" && !$opts{"����_�"}){
        # remove final "he" (not "tav", unlike the "ot" pluralization below)
        # before adding the "im" pluralization, unless the ����_� option was
        # given.
        $xword=substr($xword,0,-1);
      }
      my $xword_orig=$xword;
      if($opts{"���_�"}){
        # when the ���_� flag was given,we remove the first "em kri'a" from
        # the word in most of the inflections. (see a discussion of this
        # option in wolig.dat).
        $xword =~ s/�//o;
      }
      outword $xword."��", "�,����";
      $smichut=$xword;
      my $smichut_orig=$xword_orig;
      unless ($opts{"���_�����_����"}){
      outword $smichut_orig."�-", "�,����,������"; # smichut
      }
      # (We write patach followed by a consonant yud as "y", and later this will
      # give us the chance to automatically double it as necessary by the
      # Academia's ktiv male rules)
      unless ($opts{"���_������_����"}||$opts{"���_�����_����"}){
      outword $smichut."y",        "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."���",      "�,����,��/�����";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut."y�",       "�,����,��/��";
      outword $smichut_orig."���", "�,����,��/���";
      outword $smichut_orig."���", "�,����,��/���";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut_orig."���", "�,����,��/��";
      outword $smichut_orig."���", "�,����,��/��";
      }
    }
    if($plural_iim || $opts{"����"}){
      # The difference between ���� and ��� is that ���� adds only the "���"
      # plural, while ��� adds the plural and its inflections. For example,
      # for ������, ������, ������, �������, ��������, one would never say
      # ����� (my two years); On the other hand for other words ��� and all
      # the inflections it implies makes sense, e.g., consider ���������,
      # ������, ������.
      my $xword=$word;
      if(substr($xword,-1,1) eq "�"){
        # Change final he into tav before adding the "iim" pluralization.
        $xword=substr($xword,0,-1)."�";
      }
      my $xword_orig=$xword;
      outword $xword."y�", "�,����";
      $smichut=$xword;
      my $smichut_orig=$xword_orig;
      unless ($opts{"���_�����_����"} || !$plural_iim){
      outword $smichut_orig."�-", "�,����,������"; # smichut
      }
      unless ($opts{"���_������_����"}||$opts{"���_�����_����"} || !$plural_iim){
      outword $smichut."y",        "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."���",      "�,����,��/�����";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut."y�",       "�,����,��/��";
      outword $smichut_orig."���", "�,����,��/���";
      outword $smichut_orig."���", "�,����,��/���";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut_orig."���", "�,����,��/��";
      outword $smichut_orig."���", "�,����,��/��";
      }
    }
    if($plural_ot){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�" || substr($xword,-1,1) eq "�"){
        # remove final "he" or "tav" before adding the "ot" pluralization,
        # unless the ����_� option was given.
        if(!$opts{"����_�"}){
          $xword=substr($xword,0,-1);
        }
      }
      if($opts{"���_�"}){
        # In segoliim with cholam chaser chat that inflect like feminines
        # (i.e., the plural_ot case), the cholam is lost *only* in the base
        # plural, not in other plural inflection. This is comparable to the
        # inflections of the word ����, where the patach is lost only in the
        # base plural.
        # See for example ����, ����.
        my $tmp = $xword;
        $tmp =~ s/�//o;
        outword $tmp."��",    "�,����";
      } else {
        outword $xword."��",  "�,����";
      }

      $smichut=$xword."��";
      unless ($opts{"���_�����_����"}){
      outword $smichut."-",   "�,����,������"; # smichut
      }
      unless ($opts{"���_������_����"}||$opts{"���_�����_����"}){
      outword $smichut."y",   "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."���", "�,����,��/�����";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."y�",  "�,����,��/��";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."���", "�,����,��/��";
      outword $smichut."���", "�,����,��/��";
      }
    }
    if($plural_iot){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�" || substr($xword,-1,1) eq "�"){
        # remove final "he" or "tav" before adding the "iot" pluralization,
        # unless the ����_� option was given.
        if(!$opts{"����_�"}){
          $xword=substr($xword,0,-1);
        }
      }
      outword $xword."���",   "�,����";
      $smichut=$xword."���";
      unless ($opts{"���_�����_����"}){
      outword $smichut."-",   "�,����,������"; # smichut
      }
      unless ($opts{"���_������_����"}||$opts{"���_�����_����"}){
      outword $smichut."y",   "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."���", "�,����,��/�����";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."y�",  "�,����,��/��";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."���", "�,����,��/��";
      outword $smichut."���", "�,����,��/��";
      }
    }
    if($plural_xot){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�" || substr($xword,-1,1) eq "�"){
        # remove final "he" or "tav" before adding the "xot" pluralization,
        # unless the ����_� option was given.
        if(!$opts{"����_�"}){
          $xword=substr($xword,0,-1);
        }
      }
      outword $xword."���",   "�,����";
      $smichut=$xword."���";
      unless ($opts{"���_�����_����"}){
      outword $smichut."-",   "�,����,������"; # smichut
      }
      unless ($opts{"���_������_����"}||$opts{"���_�����_����"}){
      outword $smichut."y",   "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."���", "�,����,��/�����";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."y�",  "�,����,��/��";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."���", "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."��",  "�,����,��/���";
      outword $smichut."���", "�,����,��/��";
      outword $smichut."���", "�,����,��/��";
      }
    }
    if($plural_bizarre){
      # User specified plural for bizarre cases; For example, the plural of
      # �� is �����, the plural of �� is ����.
      # We take the fully formed plural from the user, and may need to take
      # of the ending to guess the smichut and possesives (letting the user
      # override the smichut forms too).
      my $plural=$opts{"����"};
      #outword $plural, "�,����";
      outword((exists($opts{"������"}) ? $opts{"������"} : $plural), "�,����");
      # Overriding the plural nishmach with the ������ option: David Yalin,
      # In his book ����� ����� ������ (1942) explains in page 207 how some
      # of the kinuyim are known as "kinuyey hanifrad" and some "kinuyey
      # hanishmach" because when the nismach and nifrad differ, they follow
      # different ones. This is important for words like ���, and in fact
      # the ���_� option does basically the same thing.
      my $smichut_orig;
      unless ($opts{"���_�����_����"}){
      if(substr($plural,-2,2) eq "��"){
        $smichut_orig= exists($opts{"������"}) ? $opts{"������"} : $plural;
        # as David Yalin explains (ibid.): "���� ����� �� ����� ����� ������
        # ���� ��� -�� ����� �� ������ ����� ���� ���� �������".
        $smichut=$smichut_orig;
        outword $smichut_orig."-", "�,����,������"; # smichut
      } elsif(substr($plural,-2,2) eq "��" || substr($plural,-2,2) eq "��"){
        $smichut=substr($plural,0,-2);
        # the removal of the final yod from ������ is a bit silly... maybe
        # we should have had a ����_������ option and ask it without yod.
        $smichut_orig= exists($opts{"������"}) ?
          substr($opts{"������"},0,-1) : $smichut;
        outword $smichut_orig."�-", "�,����,������"; # smichut
      } else {
        #die "Plural given for $word is of unrecognized form: $plural.";
        # An unrecognized plural form, so we don't know how to construct the
        # construct forms from it. Just ignore them.
        $opts{"���_������_����"}=1;
      }
      }
      unless ($opts{"���_������_����"}||$opts{"���_�����_����"}){
      outword $smichut."y",        "�,����,��/���"; # possessives (kinu'im)
      outword $smichut."���",      "�,����,��/�����";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut."y�",       "�,����,��/��";
      outword $smichut_orig."���", "�,����,��/���";
      outword $smichut_orig."���", "�,����,��/���";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut."��",       "�,����,��/���";
      outword $smichut_orig."���", "�,����,��/��";
      outword $smichut_orig."���", "�,����,��/��";
      }
    }
  } elsif($opts{"�"}){
    ############################# adjective ##################################
    $detail_prefix="";
    # preprocess the word the user has given, converting certain ktiv male
    # constructs into markers (w, y) that we can better work with later (see
    # comments in inword() about what it does).
    $word=inword($word);
    # A preprocessing rule special for adjectives: a final yud will always be
    # a chirik male, not some sort of consonant yud or another vowel. Together
    # with the iy post-transformation in outword, this makes ��� - ����� work
    # correctly. However, when the word ends with �� (and not ���) we assume
    # this is shuruk followed by a consonant yud (for example, ����). In
    # words that do end in ��� and the �� is not a consonant we must use a
    # w explictly, (e.g. ���� should be written explictly as �w��).
    if($word =~ m/([^aei�]|��)�$/o){
      substr($word,-1,1) = "i�";
    }

    my $xword=$word;
    if(substr($xword,-1,1) eq "�"){
      # remove final "he" before adding the pluralization,
      # unless the ����_� option was given.
      if(!$opts{"����_�"}){
        $xword=substr($xword,0,-1);
      }
    }

    if($opts{"��"}){
      # For nationality adjectives (always adding in yud!), there is a seperate
      # plural for the people of that nationality (rather than other objects
      # from that country), with only � added. There's also a country name,
      # and sometimes a female-person form too (����_�). We these here,
      # instead of seperately in extrawords, so that the country list can be
      # organized nicely at one place.
      if(exists($opts{"���"})){
        outword $opts{"���"}, "�,����,�" if($opts{"���"} ne "") # country name
      } elsif(substr($word,-3,3) eq "�i�"){
        outword substr($word,0,-3)."�", "�,����,�";  # country name
      } else {
        $country = $word;
        $country =~ s/i?�$//;
        $country =~ s/([�����])$/$fin{$1}/;
        outword $country, "�,����,�"; # country name
      }
      outword $word."�", "�,����,�"; # plural (people of that nationality)
      $opts{"����_�"}=1; # for enabling � plural. adding � plural is optional.
    }

    if(!exists($opts{"����"})){
      outword $word,     "�,����,�"; # masculin, singular
      outword $word."-", "�,����,�,������"; # smichut (same as nifrad)
    } else {
      outword $opts{"����"},     "�,����,�"; # masculin, singular
      outword $opts{"����"}."-", "�,����,�,������"; # smichut (same as nifrad)
    }
    if($opts{"�"}){
      # special case for adjectives like ����. Unlike the noun case where we
      # turn this option automatically for words ending with ��, here such a
      # default would not be useful because a lot of nouns ending with � or �
      # correspond to adjectives ending with �� that this rule doesn't fit.
      outword $xword."�",  "�,����,�"; # masculin, plural
      outword $xword."-",  "�,����,�,������"; # smichut
    } else {
      outword $xword."��", "�,����,�"; # masculin, plural
      outword $xword."�-", "�,����,�,������"; # smichut
    }
    # feminine, singular:
    my $nekeva_implicit = !($opts{"����_�"} || $opts{"����_�"} ||
                            $opts{"����_��"} || $opts{"�����"});
    # by checking for final i�, we're basically checking for final � except
    # in final �� (see comment above on where we added the i)
    my $nekeva_t = $opts{"����_�"} ||
                   ($nekeva_implicit && substr($xword,-2,2) eq "i�");
    my $nekeva_h = $opts{"����_�"} ||
                   ($nekeva_implicit && !$nekeva_t);
    my $nekeva_it = $opts{"����_��"};
    if(exists($opts{"�����"})){
      my $yechida=$opts{"�����"};
      outword $yechida,     "�,����,�";
      $yechida =~ s/�$/�/ if(!$opts{"����_�"});
      outword $yechida."-", "�,����,�,������";
    }
    if($nekeva_t){
      if(substr($word,-1,1) eq "�" && !$opts{"����_�"}){
        # This is a rare case, where an adjective ending with � gets a �
        # feminine form, and an extra yud needs to be added. For example
        # �����, ������.
        outword $xword."��",  "�,����,�";
        outword $xword."��-", "�,����,�,������"; # smichut (same as nifrad)
      } else {
        # note: we don't bother adding the vowel "e" before the � because that
        # would only make a difference before a yud - and interestingly when
        # there *is* a yud, the vowel is dropped anyway!
        outword $xword."�",   "�,����,�";
        outword $xword."�-",  "�,����,�,������"; # smichut (same as nifrad)
      }
    }
    if($nekeva_h){
      outword $xword."a�",  "�,����,�";
      outword $xword."a�-", "�,����,�,������"; # smichut
    }
    if($nekeva_it){
      outword $xword."��",  "�,����,�";
      outword $xword."��-", "�,����,�,������"; # smichut
    }
    # Feminine, plural:
    # It stays the same, regardless of the singular for. The only exception
    # is the �� feminine, where the plural becomes ���. Note that there is
    # no "else" in the if below - because we need to support the cased that
    # one word has both types of plural (e.g., see ����).
    if($nekeva_h || $nekeva_t || $opts{"�����"}){
      outword $xword."��",  "�,����,�"; # feminine, plural
      outword $xword."��-", "�,����,�,������"; # smichut (same as nifrad)
    }
    if($nekeva_it){
      outword $xword."���",  "�,����,�"; # feminine, plural
      outword $xword."���-", "�,����,�,������"; # smichut (same as nifrad)
    }
  } else {
    die "word '".$word."' was not specified as noun, adjective or verb.";
  }
  outword "-------"
}
