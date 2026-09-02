/**
 * Turns an `XFTY_InjectConfig` plus the shape of the working sub-bundle into the
 * concrete set of relationship paths the enricher materialises: a breadth start
 * walked off the bundle, plus every named `injectParent` / `injectChild` path
 * (and its prefixes), minus anything an `exclude` path covers.
 */
@IsTest
public class XFTY_EnrichmentPaths {

    public static List<List<SObjectField>> parentPaths(XFTY_DummySObjectBundle subBundle, XFTY_InjectConfig config) {
        Map<String, List<SObjectField>> byKey = new Map<String, List<SObjectField>>();
        if (config.fromAllParents && subBundle != null) {
            for (List<SObjectField> path : allDescending(subBundle, new List<SObjectField>(), config.parentDepthLimit)) {
                byKey.put(keyOf(path), path);
            }
        }
        for (List<SObjectField> included : config.includedParentPaths) {
            addWithPrefixes(included, byKey);
        }
        // a forced scalar N hops up implies materialising the chain to that record
        for (XFTY_InjectConfig.AncestorValue ancestorValue : config.ancestorValues) {
            addWithPrefixes(ancestorValue.relationshipPrefix(), byKey);
        }
        return pruned(byKey.values(), config.excludedParentPaths);
    }

    public static Set<SObjectField> childFields(XFTY_DummySObjectBundle subBundle, XFTY_InjectConfig config) {
        Set<SObjectField> fields = new Set<SObjectField>();
        if (config.fromAllChildren && subBundle != null) {
            fields.addAll(subBundle.childRelationshipFields());
        }
        for (List<SObjectField> included : config.includedChildPaths) {
            if (included.size() == 1) {
                fields.add(included[0]);
            }
        }
        for (List<SObjectField> excluded : config.excludedChildPaths) {
            if (excluded.size() == 1) {
                fields.remove(excluded[0]);
            }
        }
        return fields;
    }

    /** The paths, longest first, so a level is enriched only after everything below it. */
    public static List<List<SObjectField>> longestFirst(List<List<SObjectField>> paths) {
        Integer maxLength = 0;
        for (List<SObjectField> path : paths) {
            maxLength = Math.max(maxLength, path.size());
        }
        List<List<SObjectField>> ordered = new List<List<SObjectField>>();
        for (Integer length = maxLength; length >= 1; length--) {
            for (List<SObjectField> path : paths) {
                if (path.size() == length) {
                    ordered.add(path);
                }
            }
        }
        return ordered;
    }

    public static String keyOf(List<SObjectField> path) {
        String key = '';
        for (SObjectField step : path) {
            key += step + '>';
        }
        return key;
    }

    private static List<List<SObjectField>> allDescending(
            XFTY_DummySObjectBundle bundle,
            List<SObjectField> prefix,
            Integer remainingDepth
    ) {
        List<List<SObjectField>> paths = new List<List<SObjectField>>();
        if (remainingDepth <= 0) {
            return paths;
        }
        for (SObjectField relationshipField : materialised(bundle.relationshipFields())) {
            List<SObjectField> path = append(prefix, relationshipField);
            paths.add(path);
            XFTY_DummySObjectBundle child = bundle.getBundle(relationshipField);
            if (child != null) {
                paths.addAll(allDescending(child, path, remainingDepth - 1));
            }
        }
        return paths;
    }

    private static void addWithPrefixes(List<SObjectField> path, Map<String, List<SObjectField>> byKey) {
        for (Integer length = 1; length <= path.size(); length++) {
            List<SObjectField> prefix = prefixOf(path, length);
            byKey.put(keyOf(prefix), prefix);
        }
    }

    private static List<List<SObjectField>> pruned(
            List<List<SObjectField>> paths,
            List<List<SObjectField>> excludedPaths
    ) {
        if (excludedPaths.isEmpty()) {
            return new List<List<SObjectField>>(paths);
        }
        Set<String> excludedKeys = new Set<String>();
        for (List<SObjectField> excluded : excludedPaths) {
            excludedKeys.add(keyOf(excluded));
        }
        List<List<SObjectField>> kept = new List<List<SObjectField>>();
        for (List<SObjectField> path : paths) {
            if (!hasExcludedPrefix(path, excludedKeys)) {
                kept.add(path);
            }
        }
        return kept;
    }

    private static Boolean hasExcludedPrefix(List<SObjectField> path, Set<String> excludedKeys) {
        for (Integer length = 1; length <= path.size(); length++) {
            if (excludedKeys.contains(keyOf(prefixOf(path, length)))) {
                return true;
            }
        }
        return false;
    }

    private static List<SObjectField> prefixOf(List<SObjectField> path, Integer length) {
        List<SObjectField> prefix = new List<SObjectField>();
        for (Integer i = 0; i < length; i++) {
            prefix.add(path[i]);
        }
        return prefix;
    }

    private static List<SObjectField> append(List<SObjectField> path, SObjectField extra) {
        List<SObjectField> longer = new List<SObjectField>(path);
        longer.add(extra);
        return longer;
    }

    private static Set<SObjectField> materialised(Set<SObjectField> keySet) {
        Set<SObjectField> real = new Set<SObjectField>();
        real.addAll(keySet);
        return real;
    }
}
