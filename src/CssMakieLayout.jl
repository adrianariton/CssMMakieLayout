module CssMakieLayout
using Base.Threads
using WGLMakie
WGLMakie.activate!()
using JSServe
using Markdown
import JSServe.TailwindDashboard as D

export  hstack, vstack, wrap, zstack, active, selectclass,
        modifier, hoverable

"""
        CssMakieLayout.CurrentSession

    Session used as default for all session::Session params of the following functions. Set it at the begining of your code as such:

    ```julia
    landing2 = App() do session::Session
        CssMakieLayout.CurrentSession = session
        ...
    end
    ```
"""
CurrentSession = nothing

animtoclass(anim) = join(pushfirst!([String(s) for s in anim], ""), " anim-")
cml(class) = join(["CssMakieLayout_", class])
###################### 1. Helper functions for UX ######################
#   Functions that add css classes to DOM.div elements in order to 
#   createa a nice UX experience and also cleaner code

"""
        markdowned(figure)

    Markdown wrapper that displays `figure`'s scene content. Use it when you want simpler layouts created with Markdown.
    
    Use:
    It is optional, meaning you can also wrap the figure itself in a `wrap` function. Tipically used
    with Markdown pages.
"""
markdowned(figure) = md"""$(figure.scene)"""

"""
        wrap(content...; class, style, md=false)
    
    Wraps the content in a div element and sets the position of the div to `relative`.

    Use it to nest elements together.

    # Arguments
        - `class`: classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them
"""
wrap(content...; class="", style="", md=false) = DOM.div(JSServe.MarkdownCSS,
                                            JSServe.Styling,
                                            md ? [markdowned(i) for i in content] : content,
                                            style=style*"; position: relative;", class=class)

"""
        _hoverable(item...; class="", style="", anim=[:default], md=false)

    Wraps content in a div and adds the hoverable class to it

    # Arguments
        - `class`: additional classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them.
        - `anim`: Choose which animation to perform on hover: can be set to [:default] or [:border]
"""
_hoverable(item...; class="", style="", anim=[:default], md=false) = wrap(item; class="CssMakieLayout_hoverable "*class*" "*animtoclass(anim), style=style, md=md)

"""
hoverable(item...; stayactiveif::Observable=nothing, session::Session=CurrentSession, anim=[:default], class="", style="", md=false)
        
    Hoverable element which also stays active if the `stayactiveif` observable is set to 1. By active in the hoverable context, we mean 
    "to remain in the same state as when hovered".

    # Arguments
        - `class`: additional classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them.
        - `anim::Array`: Choose which animations to perform on hover: can be set to [:default] or [:border] or a combination of the 2
        - `stayactiveif::Observable`: If the observable set as parameter is one, the element will remain in the hovered state weather hovered or not,
                                      otherwise it will not be in the hovered state unless hovered
        - `session::Session=CurrentSession`: App session (defaults to CssMakieLayout.CurrentSession which can be set at the begining. See [`CurrentSession`](@ref))
"""
function hoverable(item...; stayactiveif::Observable=nothing, session::Session=CurrentSession, anim=[:default], class="", style="", md=false)
    if stayactiveif === nothing
        return _hoverable(item; class=class, style=style, md=md)
    end
    return selectclass(_hoverable(item; anim=anim, class=class, style=style, md=md);
                    selector=stayactiveif, session=session,
                    toggleclasses=["CssMakieLayout_stay", "_"])
end

"""
        _zstack(item...; class="", style="", md=false)

    A zstack receives an array/a tuple of elements, and displays just one of them based on the
    `observable` given as parameter. _zstack is a static version of the zstack, which is used in the main [`zstack`](@ref)
    implementation.
    It can also be used as scaffolding for user defined behaviours.
    
    # Arguments
        - `class`: additional classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them.
"""
_zstack(item...; class="", style="", md=false) = wrap(item; class="CssMakieLayout_zstack "*class, style=style)

"""
        active(item...; class="", style="", md=false)

        When constructing a layout, this function marks an element as 'active', i.e. topmost in a zstack.
    
    # Arguments
        - `class`: additional classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them.
"""
active(item...; class="", style="", md=false) = wrap(item; class="CssMakieLayout_active "*class, style=style)

"""
        zstack(item::Array; activeidx::Observable=nothing, session::Session=CurrentSession,
                class="", anim=[:default], style="", md=false)

    A zstack receives an array/a tuple of elements, and displays just one of them based on the
    `activeidx` given as parameter. The displayed (active in the context of the zstack) element can be thought of as the top of the zstack
    
    # Arguments
        - `class`: additional classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them.
        - `activeidx::Observable`: This selects the element which is displayed. For example if observable is 4,
                                    the zstack will display the 4th element of the `item` array/tuple.
        - `anim::Array`: Choose which animations to perform on transition (when `observable` is changed). Can be set to [:default], [:whoop], [:static], [:opacity] or a non-conflicting combination of them
        - `session::Session=CurrentSession`: App session (defaults to CssMakieLayout.CurrentSession which can be set at the begining. See [`CurrentSession`](@ref))

    # Example

    ```julia
        mainfigures = [Figure(backgroundcolor=:white,  resolution=config[:resolution]) for _ in 1:3]
        activefig = zstack(
                active(mainfigures[1]),
                wrap(mainfigures[2]),
                wrap(mainfigures[3]);
                activeidx=activeidx)
    ```
"""
zstack(item::Array; activeidx::Observable=nothing, session::Session=CurrentSession, class="", anim=[:default], style="", md=false) = 
    zstack(tuple(item); height=size(item)[1], activeidx=activeidx, session=session, class=class, anim=anim, style=style, md=md)

"""
    zstack(item...; activeidx::Observable=nothing, session::Session=CurrentSession,
            class="", anim=[:default], style="", md=false)

A zstack receives an array/a tuple of elements, and displays just one of them based on the
`activeidx` given as parameter (it will desplay the `activeindex`'th element). Think of it as a carousel. 

The displayed (active in the context of the zstack) will represent top of the zstack
    

# Arguments
    - `class`: additional classes of the element in a string separated with space
    - `style`: string containing the additional css style of the wrapper div
    - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
            function to each element of the content parameter before wrapping them.
    - `activeidx::Observable`: This selects the element which is displayed. For example if observable is 4,
                                the zstack will display the 4th element of the `item` array/tuple.
    - `anim::Array`: Choose which animations to perform on transition (when `activeidx` is changed). Can be set to [:default], [:whoop], [:static], [:opacity] or a non-conflicting combination of them
    - `session::Session=CurrentSession`: App session (defaults to CssMakieLayout.CurrentSession which can be set at the begining. See [`CurrentSession`](@ref))

# Example

```
    activeidx = Observable(1)
    mainfigures = [Figure(backgroundcolor=:white,  resolution=config[:resolution]) for _ in 1:3]
    activefig = zstack(
            active(mainfigures[1]),
            wrap(mainfigures[2]),
            wrap(mainfigures[3]);
            activeidx=activeidx)
```
"""
function zstack(item...; height=nothing, activeidx::Observable=nothing, session::Session=CurrentSession, class="", anim=[:default], style="", md=false) 
    if activeidx === nothing
        return _zstack(item; class=class*" "*animtoclass(anim), style=style, md=md)
    else
        if height===nothing
            height=length(item)
        end
        # static zstack
        item_div =  wrap(item; class="CssMakieLayout_zstack "*class*" "*animtoclass(anim), style=style)

        # add on(activeidx) event
        onjs(session, activeidx, js"""function on_update(new_value) {
            const activefig_stack = $(item_div)
            for(i = 1; i <= $(height); ++i) {
                const element = activefig_stack.querySelector(":nth-child(" + i +")")
                element.classList.remove("CssMakieLayout_active");
                if(i == new_value) {
                    element.classList.add("CssMakieLayout_active");
                }
            }
        }
        """)
    end

    return item_div
end

"""
        hstack(item...; class="", style="", md=false)
    
    Displays the given elements in a flex row.

    # Arguments
        - `class`: additional classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them
"""
hstack(item...; class="", style="", md=false) = wrap(item; class="CssMakieLayout_hstack "*class, style=style)

"""
        vstack(item...; class="", style="", md=false)
    
    Displays the given elements in a flex column.

    # Arguments
        - `class`: additional classes of the element in a string separated with space
        - `style`: string containing the additional css style of the wrapper div
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them
"""
vstack(item...; class="", style="", md=false) = wrap(item; class="CssMakieLayout_vstack "*class, style=style)

"""
    selectclass(item; toggleclasses=[], selector::Observable=nothing,
                session::Session=CurrentSession, class="", style="", md=false) 


Ads a class from the `toggleclasses` Array to the `item` element based on the value of the `selector` Observable.
Returns the modified item.

Use it when an element needs to quickly toggle between two or more classes based on the value of an observable. 
A simple example would be light/dark mode selection based on an observable. This can also be used hand in hand with with a
`modifier` element.

# Arguments
    - `class`: additional classes of the element in a string separated with space
    - `style`: string containing the additional css style of the wrapper div
    - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
            function to each element of the content parameter before wrapping them.
    - `toggleclasses::Array` : Array of classes to select from 
    - `selector::Observable`: Selects which class is added to the element.
    - `session::Session=CurrentSession`: App session (defaults to CssMakieLayout.CurrentSession which can be set at the begining. See [`CurrentSession`](@ref))
"""
function selectclass(item; toggleclasses=[], selector::Observable=nothing, session::Session=CurrentSession, class="", style="", md=false) 
    if selector === nothing
        return item
    else
        height = size(toggleclasses)
        # add on(observable) event
        onjs(session, selector, js"""function on_update(new_value) {
            const element = $(item)
            const cllist = $(toggleclasses)
            cllist.forEach((el) => {
                element.classList.remove(el);
            })
            element.classList.add(cllist[new_value-1]);
        }
        """)
    end

    return item
end
"""
        _button(item; class="", style="")
        
    Static button with no click events added (equivalent to hoverable).
"""
_button(item; class="", style="") = hoverable(item; class=class, style=style)


"""
modifier(item; action=:toggle, parameter::Observable=nothing, class="", style="", cap=3, step=1, md=false)

    Wrap an item in a clickable div (modifier element/button) and bind it to an observable. When clicked, it modifies the `parameter` Observable taken as parameter based on the button's `action`, `cap` and `step`.
    `action` can be: :toggle, :increase, :decrease, :increasemod, :decreasemod
              :increasecap, :decreasecap

    Use it when you need to modify the value of an observale based on the number of click events on an element.
    Examples could range from 

    - play/pause, dark/light mode (togglers)
    - previous/next (decreasecap/increasecap or decreasemod/increasemod for loopback)

    # Arguments
        - `class`: additional classes of the modifier element in a string separated with space
        - `style`: string containing the additional css style of the modifier
        - `md`: Set to false unless specified otherwise. Specifies weather to aply the [`markdowned`](@ref)
                function to each element of the content parameter before wrapping them.
        - `parameter::Observable`: Observable that is modified when a click event is triggered on the modifier.
        - `action`: The way that the modifier button modifies it's `parameter` when clicked:    
                    - `:toggle`: toggles the observable from 0 to 1, or from 1 to 0 (for example 1 - play, 0 - pause)
                    -  `:increase`, `decrease`: increase or decrease the observable by `step`
                    - `:increasemod`, `decreasemod`: increase or decrease the observable by `step` nd then take the modulo w.r.t `cap` and add 1, to keep the number in the [1, cap] interval
                    - `:increasecap`, `:decreasecap`: increase or decrease the observable by `step`, keep it in the [1, cap] interval, but do not increase/decrease when increasing and decreasing would make the observable exit the interval (as oposed to the mod option which loops back, the cap option stays there).
        - `step`, `cap`: the step of the increase/decrease steps and the maximum cappacity
    
    # Example 

    The modifier element can be used hand in hand with a zstack element to create reactive layouts as such:
    ```julia
    mainfigures = [Figure(backgroundcolor=:white,  resolution=config[:resolution]) for _ in 1:3]
    buttons = [modifier(wrap(DOM.h1("〈")); action=:decreasecap, parameter=activeidx, cap=3, style=buttonstyle),
                modifier(wrap(DOM.h1("〉")); action=:increasecap, parameter=activeidx, cap=3, style=buttonstyle)]
    activefig = zstack(
                    active(mainfigures[1]),
                    wrap(mainfigures[2]),
                    wrap(mainfigures[3]);
                    observable=activeidx)
    layout = hstack(buttons[1], activefig, buttons[2])
    ```
"""
function modifier(item; action=:toggle, parameter::Observable=nothing, class="", style="", cap=3, step=1, md=false)
    if parameter === nothing
        return _button(item; class=class, style=style)
    end
    t = D.Button(item; class=class, style=style)
    on(t) do event
        if action == :toggle
            parameter[] = parameter[]
        elseif action == :increase
            parameter[] = parameter[] + step
        elseif action == :decrease
            parameter[] = parameter[] - step
        elseif action == :increasemod
            parameter[] = parameter[] + step
            if parameter[] >= cap + 1
                parameter[] = 1
            end
        elseif action == :decreasemod
            parameter[] = parameter[] - step
            if parameter[] <= 0
                parameter[] = cap
            end
        elseif action == :increasecap
            parameter[] = parameter[] + step
            if parameter[] >= cap + 1
                parameter[] = parameter[] - step
            end
        elseif action == :decreasecap
            parameter[] = parameter[] - step
            if parameter[] <= 0
                parameter[] =  parameter[] + step
            end
        end
    end
    return wrap(t; class="CssMakieLayout_btn")
end
"""
        CssMakieLayout.formatstyle
    
    CSS code used by the library for styling

    Include it in your layout when returning the final element as such:
    ```julia
    return hstack(CssMakieLayout.formatstyle, layout)
    ```
"""
const formatstyle=DOM.style("""
    .CssMakieLayout_hoverable.anim-default{
        transition: all 0.1s ease;
    }
    .CssMakieLayout_hoverable.anim-default:hover, .CssMakieLayout_stay.anim-default{
        transform: scale(1.1);
    }

    .CssMakieLayout_hoverable.anim-border{
        transition: all 0.1s ease;
        border: 2px solid transparent;

    }
    .CssMakieLayout_hoverable.anim-border:hover, .CssMakieLayout_stay.anim-border{
        border: 2px solid black;
    }

    .CssMakieLayout_hoverable.anim-border.white{
        transition: all 0.1s ease;
        border: 2px solid transparent;
        padding: 4px;
        padding-bottom: 0px;

    }
    .CssMakieLayout_hoverable.anim-border.white:hover, .CssMakieLayout_stay.white.anim-border{
        border: 2px solid white;
    }


    .CssMakieLayout_hstack{
        display:flex;
        flex-direction: row;
    }

    .CssMakieLayout_vstack{
        display: flex;
        flex-direction: column;
    }

    .align-center{
        align-items: center;
    }

    .justify-center{
        justify-content: center;
    }

    .CssMakieLayout_zstack{
        display:flex;
        flex-direction: row;
    }

    .CssMakieLayout_zstack, .CssMakieLayout_zstack > *{
        transition: all 0.3s ease;
    }

    .CssMakieLayout_zstack.anim-default .CssMakieLayout_active{
        transition: all 0.3s ease;
        width: 100%;
        overflow: hidden;

    }

    .CssMakieLayout_zstack.anim-default > :not(.CssMakieLayout_active){
        transition: all 0.3s ease;
        width: 0%;
        overflow: hidden;
    }

    .CssMakieLayout_zstack.anim-whoop{
        display: grid;
    }

    .CssMakieLayout_zstack.anim-whoop > *{
        grid-area: 1/1/1/1;

    }

    .CssMakieLayout_zstack.anim-whoop .CssMakieLayout_active{
        z-index: 4;
        position: absolute;
        transition: all 0.3s ease;
        transform: scale(1);
        overflow: hidden;

    }

    .CssMakieLayout_zstack.anim-whoop > :not(.CssMakieLayout_active){
        position: absolute;
        z-index: 1;

        transition: all 0.3s ease;
        transform: scale(0);
        overflow: hidden;
    }

    .CssMakieLayout_zstack.anim-static .CssMakieLayout_active{
        overflow: hidden;

    }

    .CssMakieLayout_zstack.anim-static > :not(.CssMakieLayout_active){
        width: 0px;
        overflow: hidden;
    }

    .CssMakieLayout_zstack.anim-opacity .CssMakieLayout_active{
        transition: all 0.1s ease;
        opacity: 1;

    }

    .CssMakieLayout_zstack.anim-opacity > :not(.CssMakieLayout_active){
        transition: all 0.1s ease;
        opacity: 0;
    }

    .upper{
        text-transform: uppercase;
    }
    .CssMakieLayout_btn button{
        height: 100%;
        width: 100%;
    }
    .CssMakieLayout_btn button:hover{
        box-shadow: rgba(50, 50, 93, 0.25) 0px 30px 60px -12px inset, rgba(0, 0, 0, 0.3) 0px 18px 36px -18px inset !important;
    }


    """)

const Themes = Dict(
    :elegant => function fct(config)
        return DOM.style("""
        .CssMakieLayout_btn button{
            background-color: $(config[:colorscheme][1]);
            color: $(config[:colorscheme][2]);
            border: none !important;
        }""")
    end,
)

end # module CssMakieLayout
