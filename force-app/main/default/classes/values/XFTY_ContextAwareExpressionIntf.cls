/**
 * A value expression that needs the surrounding generation context - sibling fields
 * on the record being built, or fields on a generated ancestor.
 *
 * This is a **separate** interface from `XFTY_ValueExpressionIntf`, not a
 * subtype of it: a context-aware value genuinely cannot produce anything without
 * a context, so making it satisfy the no-argument `get()` contract would be a
 * lie. The Master Template holds context-aware expressions in their own slot and
 * the engine calls {@link #get(XFTY_GenerationContext)} in a second pass, after
 * the plain values are filled and the ancestor records exist.
 *
 * `put(field, someObject)` accepts an `XFTY_ContextAwareExpressionIntf` directly;
 * anything that is neither this, a plain value expression, nor a relationship is
 * treated as an exact literal.
 *
 * See docs/roadmap/context-aware-values.md.
 */
//@IsTest
public interface XFTY_ContextAwareExpressionIntf {
    Object get(XFTY_GenerationContext context);
}
