(function(){
  var sync, http, url, toString$ = {}.toString;
  sync = require('sync');
  http = require('http');
  url = require('url');
  String.prototype.pipe = Buffer.prototype.pipe = function(it){
    return it.end(this.constructor(this));
  };
  module.exports = function(routes){
    routes == null && (routes = []);
    function route(method){
      return function(path, funcs){
        var reg, params;
        reg = (function(){
          switch (toString$.call(path).slice(8, -1)) {
          case 'String':
            params = unfold(function(arg$){
              var ident, part, that;
              ident = arg$[0], part = arg$[1];
              if (that = ident.exec(part)) {
                return [that[1], [ident, part.replace(ident, '([^\\/]+)')]];
              } else {
                path = part;
                return null;
              }
            })(
            [/:([a-z$_][a-z0-9$_]*)/i, path]);
            return RegExp("^" + path + "$", 'i');
          case 'RegExp':
            return path;
          case 'Function':
            return {
              test: path,
              exec: path
            };
          default:
            throw new TypeError("Invalid path " + path);
          }
        }());
        each(bind$(routes, 'push'))(
        concatMap(compose$([
          (function(it){
            return import$(it, {
              match: function(it){
                return (method == 'ANY' || method == it.method) && reg.test(it.pathname);
              },
              handle: function(req, res){
                var vals, ref$, that, this$ = this;
                vals = (ref$ = reg.exec(req.pathname)) != null
                  ? ref$
                  : [];
                import$((ref$ = (req.statusCode = 200, req)).params || (ref$.params = {}), (that = params) != null ? listToObj(
                zip(that)(
                tail(vals))) : vals);
                if (res.skip && !it.always) {
                  return id;
                } else {
                  return function(last){
                    return it.sync(req, res, last);
                  };
                }
              }
            });
          }), function(it){
            return it.async();
          }
        ]))(
        [].concat(funcs)));
        return this;
      };
    }
    return import$(http.createServer(function(req, res){
      return sync(function fiber(){
        return (function(start, end$){
          var r;
          res.end = function(){
            console.log(res.statusCode + " " + req.url + ": " + (Date.now() - start) + "ms");
            return end$.apply(this, arguments);
          };
          import$(req, url.parse(req.url, true)).statusCode = 404;
          return fold(curry$(function(x$, y$){
            return y$(x$);
          }), "404 " + req.pathname, (function(){
            var i$, ref$, len$, results$ = [];
            for (i$ = 0, len$ = (ref$ = routes).length; i$ < len$; ++i$) {
              r = ref$[i$];
              if (r.match(req)) {
                results$.push(r.handle(req, res));
              }
            }
            return results$;
          }())).pipe(res);
        }.call(this, Date.now(), res.end));
      }, function error(it){
        if (it != null) {
          return (res.statusCode = 500, res).end(it.stack);
        }
      });
    }), map(route, {
      'ANY': 'ANY',
      'GET': 'GET',
      'POST': 'POST',
      'PUT': 'PUT',
      'DELETE': 'DELETE',
      'OPTIONS': 'OPTIONS',
      'TRACE': 'TRACE',
      'CONNECT': 'CONNECT',
      'HEAD': 'HEAD',
      use: function(it){
        var ref$;
        return routes.push((ref$ = it.async(), ref$.match = function(){
          return true;
        }, ref$.handle = function(req, res){
          return function(last){
            return it.sync(req, res, last);
          };
        }, ref$));
      }
    }));
  };
  function bind$(obj, key, target){
    return function(){ return (target || obj)[key].apply(obj, arguments) };
  }
  function compose$(fs){
    return function(){
      var i, args = arguments;
      for (i = fs.length; i > 0; --i) { args = [fs[i-1].apply(this, args)]; }
      return args[0];
    };
  }
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
  function curry$(f, args){
    return f.length > 1 ? function(){
      var params = args ? args.concat() : [];
      return params.push.apply(params, arguments) < f.length && arguments.length ?
        curry$.call(this, f, params) : f.apply(this, params);
    } : f;
  }
}).call(this);
