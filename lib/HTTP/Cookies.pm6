class HTTP::Cookies;

use HTTP::Cookie;
use HTTP::Response;
use HTTP::Request;
use DateTime::Parse;

has @.cookies;
has $.file;
has $.autosave is rw = 0;

my grammar HTTP::Cookies::Grammar {
    token TOP {
        'Set-Cookie:' [\s* <cookie> ','?]*
    }

    token cookie   {
        <name> '=' <value> ';'? \s* [<arg> \s*]* <secure>? ';'? \s* <httponly>? ';'?
    }
    token name     { \w+ }
    token value    { <[\w \s , / :]>+ }
    token arg      { <name> '=' <value> ';'? }
    token secure   { Secure }
    token httponly { HttpOnly }
}

my class HTTP::Cookies::Actions {
    method cookie($/) {
        my $h = HTTP::Cookie.new;
        $h.name     = ~$<name>;
        $h.value    = ~$<value>;
        $h.secure   = $<secure>.defined ?? ~$<secure> !! False;;
        $h.httponly = $<httponly>.defined ?? ~$<httponly> !! False;

        for $<arg>.list -> $a {
            $h.fields.push: $a<name> => ~$a<value>;
        }

        $*OBJ.push-cookie($h);
    }
}

method extract-cookies(HTTP::Response $response) {
    self.set-cookie($_) for $response.header('Set-Cookie').map({ "Set-Cookie: $_" });
    self.save if $.autosave;
}

method add-cookie-header(HTTP::Request $request) {
    for @.cookies -> $cookie {
        next if $cookie.fields<Domain>.defined
                && $cookie.fields<Domain> ne $request.header('Host');
        # TODO : path restrictions

        if $request.header('Cookie').defined {
            $request.push-header( Cookie => $cookie.Str );
        } else {
            $request.header( Cookie => $cookie.Str );
        }
    }
}

method save {
    my $fh = open $.file, :w;

    # TODO : add versioning
    $fh.say: "#LWP6-Cookies-0.1";
    $fh.say: self.Str;

    $fh.close;
}

method load {
    for $.file.IO.lines -> $l {
        # we don't need #LWP6-Cookies-$VER
        next if $l.substr(0, 1) eq '#';
        self.set-cookie($l.chomp);
    }
}

method clear-expired {
    @.cookies .= grep({
        !.fields<Expires>.defined ||
        # we need more precision
        DateTime::Parse.new( .fields<Expires> ).Date > Date.today
    });
    self.save if $.autosave;
}

method clear {
    @.cookies = ();
    self.save if $.autosave;
}

method set-cookie($str) {
    my $*OBJ = self;
    HTTP::Cookies::Grammar.parse($str, :actions(HTTP::Cookies::Actions));

    self.save if $.autosave;
}

method push-cookie(HTTP::Cookie $c) {
    @.cookies .= grep({ .name ne $c.name });
    @.cookies.push: $c;

    self.save if $.autosave;
}

method Str {
    @.cookies.map({ "Set-Cookie: {$_.Str}" }).join("\n");
}

=begin pod

=head1 NAME

HTTP::Cookies - HTTP cookie jars

=head1 SYNOPSIS

    use HTTP::Cookies;
    my $cookies = HTTP::Cookies.new(
        :file<./cookies>,
        :autosave(1)
    );
    $cookies.load;

=head1 DESCRIPTION

TODO

=head1 METHODS

=head2 method new

    multi method new(*%params)

=head2 method save

    method save(HTTP::Cookies:)

=head2 method load

    method load(HTTP::Cookies:)

=head2 method extract-cookies

    method extract-cookies(HTTP::Cookies:, HTTP::Response $response)

=head2 method add-cookie-header

    method add-cookie-header(HTTP::Cookies:, HTTP::Request $request)

=head2 method clear-expired

    method clear-expired(HTTP::Cookies:)

=head2 method clear

    method clear(HTTP::Cookies:)

=head2 method set-cookie

    method set-cookie(HTTP::Cookies:, Str $str)

=head2 method push-cookie

    method push-cookie(HTTP::Cookies:, HTTP::Cookie $c)

=head2 method Str

    method Str(HTTP::Cookies:)

=head1 SEE ALSO

L<HTTP::Request>, L<HTTP::Response>, L<HTTP::Cookie>

=head1 AUTHOR

Filip Sergot (sergot)

=end pod
