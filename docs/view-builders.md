# View Builders

AUI supports **view-returning function calls** in `body()`. Methods that return `View` are automatically inlined by the ComposeGenerator at compile time.

## Instance methods

Define helper methods on your App class:

```haxe
class MyApp extends App {
    @:state var task1Done:Bool = false;
    @:state var task2Done:Bool = false;

    function taskItem(title:String, done:aui.state.State<Bool>):View {
        return new ConditionalView(done,
            new Text(title).foregroundColor(ColorValue.Gray).opacity(0.5),
            new HStack([
                new Text(title),
                new Spacer(),
                new Button("Done", done.tog())
            ])
        );
    }

    override function body():View {
        return new VStack([
            taskItem("First task", task1Done),
            taskItem("Second task", task2Done)
        ]);
    }
}
```

The macro detects that `taskItem()` returns `View`, looks up the method body, binds the call arguments to the parameter names, and inlines the translated output. This means you can write DRY code without repeating view structures.

## How it works

1. The macro encounters `TCall(TField(this, "taskItem"), args)` in the AST
2. It checks if `taskItem` has a return type of `View` (or subclass)
3. It binds the call arguments to the function's parameter IDs
4. It translates the function body as if it were written inline
5. State field references passed as parameters are resolved through the binding chain

## Limitations

- The method must have a return type of `View` or a subclass
- Parameters referencing state fields must be `State<T>` typed for state actions to resolve
- Recursive view builders are not supported
- The function body is re-translated for each call site (true inlining)
