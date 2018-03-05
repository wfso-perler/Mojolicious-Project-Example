package Example::Util;

use strict;
use warnings;

use Exporter qw/import/;
use CGI::Carp qw/confess/;
use Data::UUID;
use Crypt::PK::RSA;
use Digest::SHA;
use Digest::MD5;
use JSON;
use Scalar::Util;
use MIME::Base64 qw/encode_base64 decode_base64/;
use utf8;
use Mojo::Util qw/url_escape/;
use Encode qw/encode_utf8/;
use Digest::HMAC_SHA1;

our @EXPORT_OK = qw/md5 rsaDecrypt rsaEncrypt rsaSignMsg rsaVerifyMsg getRSAKey getUUID hmacSHA256Hex encodeJSON decodeJSON orderEncodeJSON trim check_file_type wxSign aliSMSSign hmacSHA1Base64 aliUrlEscape sha1Hex/;


## @author wfso
## @param {string|array{string}}
## @returns {string} 对“参数”计算得到的md5摘要信息的十六进制表示(一个长度为32个字符的字符串)
## @description 非加密算法，而是计算“参数”的md5摘要，得到“参数”摘要的十六进制表示
sub md5{
  my (@data) = @_;
  my $md5 = Digest::MD5->new();
  $md5->add(@data);
  return $md5->hexdigest;
}

## @author wfso
## @param {string} key
## @param {string|array{string}} data
## @returns {string} sha256摘要信息的十六进制表示(一个长度为64个字符字符串)
sub hmacSHA256Hex{
  my ($key, @data) = @_;
  my $t = "";
  foreach(@data){
    $t .= $_;
  }
  return Digest::SHA::hmac_sha256_hex($t, $key);
}


## @author wfso
## @param {string} key
## @param {string|array{string}} data
## @returns {string} sha1摘要信息的Base64表示
sub hmacSHA1Base64{
  my ($key, @data) = @_;
  my $t = "";
  foreach(@data){
    $t .= $_;
  }
  return encode_base64(Digest::SHA::hmac_sha1($t, $key));
}


sub sha1Hex{
  my $t = "";
  foreach(@_){
    $t .= $_;
  }
  return Digest::SHA::sha1_hex($t);
}

## @author wfso
## @param $pubkey 加密用到的公钥，可以是 Crypt::PK::RSA 支持的所有类型的公钥
## @param $data  待加密数据
## @param $padding  'v1.5' (DEFAULT), 'oaep' or 'none' (INSECURE)
## @param $hash_name (only for oaep) .. 'SHA256' (DEFAULT), 'SHA1' or any other hash supported by Crypt::Digest
## @param $lparam (only for oaep) ..... DEFAULT is empty string
sub rsaEncrypt{
  my ($pubkey, $data, $padding, $hasName, $lparam) = @_;
  $lparam ||= '';
  $padding ||= 'v1.5';
  $hasName ||= 'SHA256';
  my $pk = Crypt::PK::RSA->new($pubkey);
  
  ## 判断每次加密支持的最大长度
  my $size = $pk->size;
  if($padding eq "v1.5"){
    $size -= 11;
  }elsif($padding eq "oaep"){
    if($hasName eq "MD5"){
      $size -= 34;
    }elsif($hasName eq "SHA1"){
      $size -= 42;
    }elsif($hasName eq "SHA256"){
      $size -= 66;
    }else{
      confess "Don't support the hash_name '$hasName' ";
    }
  }
  
  ## 对需要加密的数据进行分块
  my @dlist;
  if(length($data) > $size){
    @dlist = $data =~ /.{$size}/sg;
    push(@dlist, substr($data, scalar(@dlist) * $size));
  }else{
    push(@dlist, $data);
  }
  
  ## 分块加密
  my @result;
  foreach(@dlist){
    push(@result, encode_base64($pk->encrypt($_, $padding, $hasName, $lparam)));
  }
  
  ## 拼接结果并返回
  return join(";", @result);
}


## @author wfso
## @param $prikey 解密用到的私钥，可以是 Crypt::PK::RSA 支持的所有类型的私钥
## @param $ciphertext  待密码的数据
## @param $padding  'v1.5' (DEFAULT), 'oaep' or 'none' (INSECURE)
## @param $hash_name (only for oaep) .. 'SHA256' (DEFAULT), 'SHA1' or any other hash supported by Crypt::Digest
## @param $lparam (only for oaep) ..... DEFAULT is empty string
sub rsaDecrypt{
  my ($prikey, $ciphertext, $padding, $hasName, $lparam) = @_;
  $lparam ||= '';
  $padding ||= 'v1.5';
  $hasName ||= 'SHA256';
  my $pk = Crypt::PK::RSA->new($prikey);
  
  ## 切片得到加密单元
  my @dlist = split(/;/, $ciphertext);
  
  ## 分段解密得到明文
  my $result = "";
  foreach(@dlist){
    $result .= $pk->decrypt(decode_base64($_), $padding, $hasName, $lparam);
  }
  
  return $result;
}

## @author wfso
## @param $prikey  用于签名的 私钥， 可以是 Crypt::PK::RSA 支持的所有类型的私钥
## @param $data   待签名的信息
## @param $hash_name ...... 'SHA256' (DEFAULT), 'SHA1' or any other hash supported by Crypt::Digest
## @param $padding ....... 'v1.5' (DEFAULT) or 'pss' or 'none' (INSECURE)
## @param $saltlen (only for pss) .. DEFAULT is 12
## description 对信息进行签名
sub rsaSignMsg{
  my ($prikey, $data, $hasName, $padding, $saltlen) = @_;
  $hasName ||= "SHA256";
  $padding ||= "v1.5";
  $saltlen ||= 12;
  my $pk = Crypt::PK::RSA->new($prikey);
  return encode_base64($pk->sign_message($data, $hasName, $padding, $saltlen));
}

## @author wfso
## @param $pubkey  用于验证签名的 公钥， 可以是 Crypt::PK::RSA 支持的所有类型的公钥
## @param $signature 签名数据
## @param $data   待验证的信息
## @param $hash_name ...... 'SHA256' (DEFAULT), 'SHA1' or any other hash supported by Crypt::Digest
## @param $padding ....... 'v1.5' (DEFAULT) or 'pss' or 'none' (INSECURE)
## @param $saltlen (only for pss) .. DEFAULT is 12
## description 对签名进行验证
sub rsaVerifyMsg{
  my ($pubkey, $signature, $data, $hashName, $padding, $saltlen) = @_;
  $hashName ||= "SHA256";
  $padding ||= "v1.5";
  $saltlen ||= 12;
  my $pk = Crypt::PK::RSA->new($pubkey);
  return $pk->verify_message(decode_base64($signature), $data, $hashName, $padding, $saltlen);
}


## @author wfso
## @description 随机生成一个 2048 位的 RSA 密钥对
## 以 PEM 格式字符串的进行返回 公钥 和 密钥
sub getRSAKey{
  my $pk = Crypt::PK::RSA->new();
  $pk->generate_key();
  my $result = {};
  $result->{pubkey} = $pk->export_key_pem("public_x509");
  $result->{prikey} = $pk->export_key_pem("private");
  return $result;
}



## @author wfso
## @description 生成一个全局的唯一标识 UUID 并返回
sub getUUID{
  return Data::UUID->new->create_str();
}

## JSON编码 JSON转化为字符串
sub encodeJSON{
  my $json = JSON->new->allow_nonref->utf8;
  return $json->encode(shift());
}

## Json解码  字符串转化为JSON
sub decodeJSON{
  my $json = JSON->new->allow_nonref->utf8;
  return $json->decode(shift());
}

sub orderEncodeJSON{
  my $obj = shift;
  my $order = shift || "asc";
  if(ref $obj eq "HASH"){
    my $result = "";
    if(lc($order) eq "asc"){
      for my $k (sort(keys %{$obj})){
        $result .= orderEncodeJSON($obj->{$k});
      }
    }else{
      for my $k (sort {$b <=> $a} (keys %{$obj})){
        $result .= orderEncodeJSON($obj->{$k});;
      }
    }
    return $result;
  }
  if(ref $obj eq "ARRAY"){
    my $result = "";
    for my $el (@{$obj}){
      $result .= orderEncodeJSON($el);
    }
    return $result;
  }
  if(ref $obj eq "SCALAR"){
    return ${$obj};
  }
  if(defined $obj && !ref $obj){
    return $obj;
  }
  return "";
}


## 去除输入值前后空格
sub trim{
  my $str = shift();
  $str =~ s/^\s+|\s+$//sg;
  return $str;
}

sub check_file_type{
  my $filename = shift;
  my $filetype = shift;
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
  if($filetype && $type_map->{$filetype}){
    if($filename =~ $type_map->{$filetype}){
      return $1;
    }
  }
  return undef;
}

sub wxSign{
  my $sign_type = uc(shift);
  my $sign_key = shift;
  my $obj = shift;
  my $str = "";
  for (sort keys %{$obj}){
    if(length($str)){
      $str .= "&$_=$obj->{$_}" if(length($obj->{$_}));
    }else{
      $str .= "$_=$obj->{$_}" if(length($obj->{$_}));
    }
  }
  $str .= "&key=" . $sign_key;
  if($sign_type eq "MD5"){
    return uc(md5($str));
  }
  if($sign_type eq "HMAC-SHA256"){
    return uc(hmacSHA256Hex($sign_key, $str));
  }
  return undef;
}


sub aliSMSSign{
  my $sign_key = shift;
  my $obj = shift;
  my $str = "";
  for (sort keys %{$obj}){
    if(length($str)){
      $str .= '&' . aliUrlEscape($_) . "=" . aliUrlEscape(encode_utf8($obj->{$_}));
    }else{
      $str .= aliUrlEscape($_) . "=" . aliUrlEscape(encode_utf8($obj->{$_}));
    }
  }
  my $sign = "GET&" . aliUrlEscape("/") . "&" . aliUrlEscape($str);
  my $signature = hmacSHA1Base64($sign_key, $sign);
  $signature =~ s/^\s+//s;
  $signature =~ s/\s+$//s;
  return "Signature" . "=" . aliUrlEscape($signature) . "&" . $str;
}

sub aliUrlEscape{
  my $str = shift;
  $str = url_escape($str);
  $str =~ s/\+/\%20/g;
  $str =~ s/\*/\%2A/g;
  $str =~ s/\%7E/\~/g;
  return $str;
}


1;