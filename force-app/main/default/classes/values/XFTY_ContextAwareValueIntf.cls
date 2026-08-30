/**
 * A value strategy that needs the surrounding generation context - sibling fields
 * on the record being built, or fields on a generated ancestor.
 *
 * Extends `XFTY_DummyDefaultValueIntf` so it drops into a Master Template exactly
 * like a plain strategy. The engine calls {@link #get(XFTY_GenerationContext)}
 * in a second pass, after the plain values are filled and the ancestor records
 * exist; the inherited no-arg `get()` should throw, because it is only reached
 * where the engine has no context to give (which should not happen in normal
 * generation).
 *
 * See docs/design/context-aware-values.md.
 */
//@IsTest
public interface XFTY_ContextAwareValueIntf extends XFTY_DummyDefaultValueIntf {
    Object get(XFTY_GenerationContext context);
}
