#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Plack::Test;

use utf8;

{
    package Foo::Controller;
    use Moose;

    sub query {
        my $self = shift;
        my ($r) = @_;

        my $got = $r->param("query");
        ::ok(utf8::is_utf8($got), "query param is encoded");
        ::is($got, "café", "got the correct query param value");

        return "déjà vu";
    }

    sub body {
        my $self = shift;
        my ($r) = @_;

        my $got = $r->param("body");
        ::ok(utf8::is_utf8($got), "body param is encoded");
        ::is($got, "café", "got the correct body param value");

        return "déjà vu";
    }

    sub content {
        my $self = shift;
        my ($r) = @_;

        my $got = $r->content;
        ::ok(utf8::is_utf8($got), "content is encoded");
        ::is($got, "出国まで四日間だけか", "body content encoded correctly");

        return "インド料理を食い過ぎた。うめええ";
    }
}

{
    package Foo;
    use OX;

    has controller => (
        is  => 'ro',
        isa => 'Foo::Controller',
    );

    router as {
        route '/query'   => 'controller.query';
        route '/body'    => 'controller.body';
        route '/content' => 'controller.content';
    };
}

test_psgi
    app    => Foo->new->to_app,
    client => sub {
        my $cb = shift;
        {
            my $req = HTTP::Request->new(
                GET => 'http://localhost/query?query=caf%C3%A9'
            );
            my $res = $cb->($req);
            my $content = $res->content;
            ok(!utf8::is_utf8($content), "raw content is in bytes");
            my $expected = "déjà vu";
            utf8::encode($expected);
            is($content, $expected, "got utf8 bytes");
        }
        {
            my $req = HTTP::Request->new(
                POST => 'http://localhost/body',
                ['Content-Type' => 'application/x-www-form-urlencoded'],
                'body=caf%C3%A9'
            );
            my $res = $cb->($req);
            my $content = $res->content;
            ok(!utf8::is_utf8($content), "raw content is in bytes");
            my $expected = "déjà vu";
            utf8::encode($expected);
            is($content, $expected, "got utf8 bytes");
        }
        {
            my $body = '出国まで四日間だけか';
            utf8::encode($body);
            my $req = HTTP::Request->new(
                POST => 'http://localhost/content',
                [],
                $body
            );
            my $res = $cb->($req);
            my $content = $res->content;
            ok(!utf8::is_utf8($content), "raw content is in bytes");
            my $expected = "インド料理を食い過ぎた。うめええ";
            utf8::encode($expected);
            is($content, $expected, "got utf8 bytes");
        }
    };

done_testing;
