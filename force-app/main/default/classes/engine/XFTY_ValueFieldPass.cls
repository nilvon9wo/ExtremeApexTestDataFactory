/**
 * The narrowest scope of a generation run: the single value field whose
 * context-aware expression is running right now, plus the set of context-aware
 * value fields on the same record that have *not* been generated yet.
 *
 * `pendingContextAwareValues` is what lets the engine tell "this sibling has not
 * been computed yet" apart from "this sibling was computed and the answer is
 * `null`": a field still in the set has no value because its strategy has not
 * run; a field absent from the set holds its real, final value (possibly `null`).
 * {@link XFTY_GenerationContext#siblingValue} refuses a read of a still-pending
 * field loudly rather than handing back a misleading `null`.
 *
 * Set only during {@link XFTY_ContextAwareValuePass}; `null` on the context
 * everywhere else.
 */
public class XFTY_ValueFieldPass {
    public final SObjectField fieldBeingBuilt;
    public final Set<SObjectField> pendingContextAwareValues;

    public XFTY_ValueFieldPass(SObjectField fieldBeingBuilt, Set<SObjectField> pendingContextAwareValues) {
        this.fieldBeingBuilt = fieldBeingBuilt;
        this.pendingContextAwareValues = pendingContextAwareValues;
    }
}
