package Example::Plugin::ExtendValidator;
use Mojo::Base 'Mojolicious::Plugin';
use Data::Dumper;

sub register{
  my ($self, $app) = @_;
  
  my $type_map = {
    image    => qr/(\.jpg|\.jpeg|\.png|\.gif|\.bmp)$/i,
    jpeg     => qr/(\.jpeg)$/i,
    png      => qr/(\.png)$/i,
    gif      => qr/(\.gif)$/i,
    bmp      => qr/(\.bmp)$/i,
    doc      => qr/(\.doc)$/i,
    ppt      => qr/(\.ppt)$/i,
    xls      => qr/(\.xls)$/i,
    docx     => qr/(\.docx)$/i,
    pptx     => qr/(\.pptx)$/i,
    xlsx     => qr/(\.xlsx)$/i,
    pdf      => qr/(\.pdf)$/i,
    txt      => qr/(\.txt)$/i,
    compress => qr/(\.rar|\.zip|\.7z|\.tar|\.gz|\.tgz)$/i,
    rar      => qr/(\.rar)$/i,
    zip      => qr/(\.zip)$/i,
    "7z"     => qr/(\.7z)$/i,
    tar      => qr/(\.tar)$/i,
    gz       => qr/(\.gz)$/i,
    tgz      => qr/(\.tgz)$/i
  };
  
  my $validator = $app->validator;
  $validator->add_check(mobile_phone_number => sub{
      my ($validation, $name, $value) = @_;
      return "[$name:$value] is not a mobile phone number" if($value !~ /^1[\d]{10}$/);
      return undef;
    }
  );
  
  $validator->add_check(id_card_number => sub{
      my ($validation, $name, $value) = @_;
      return "[$name:$value] is not a id_card number" if($value !~ /^[\dxX]{18}$/);
      return undef;
    }
  );
  
  $validator->add_check(email_address => sub{
      my ($validation, $name, $value) = @_;
      return "[$name:$value] is not a email address" if($value !~ /^[\w]+\@[\w]+\.[\w\.]+$/);
      return undef;
    }
  );
  
  $validator->add_check(date => sub{
      my ($validation, $name, $value) = @_;
      return "[$name:$value] is not a date" if($value !~ /^[\d]{4}-[\d]{1,2}-[\d]{1,2}$/);
      return undef;
    }
  );
  
  $validator->add_check(datetime => sub{
      my ($validation, $name, $value) = @_;
      return "[$name:$value] is not a datetime" if($value !~ /^[\d]{4}-[\d]{1,2}-[\d]{1,2} [\d]{2}:[\d]{2}:[\d]{2}$/);
      return undef;
    }
  );
  
  $validator->add_check(color => sub{
      my ($validation, $name, $value) = @_;
      return "[$name:$value] is not a color value，e: #1f0a3b " if($value !~ /^#[\da-f]{6}$/i);
      return undef;
    }
  );
  
  $validator->add_check(decimal => sub{
      my ($validation, $name, $value) = @_;
      return "[$name:$value] is not a decimal " if($value !~ /^[0-9]+(?:\.[0-9]+)?$/i);
      return undef;
    }
  );
  
  $validator->add_check(file_type => sub{
      my ($validation, $name, $value, $file_type) = @_;
      return "[$name:$value] is not a upload file " if(!ref $value || !$value->isa('Mojo::Upload'));
      my $filename = $value->filename;
      if($file_type && $type_map->{$file_type}){
        if($filename =~ $type_map->{$file_type}){
          $value->{ext_name} = $1;
          return undef;
        }
      }
      return "[$name:$value] is not a [$file_type] type file";
    }
  );
  
}







1;