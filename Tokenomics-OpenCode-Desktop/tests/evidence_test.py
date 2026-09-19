import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('evidence', Path(__file__).resolve().parents[1] / 'tools/evidence.py')
e = importlib.util.module_from_spec(spec)
spec.loader.exec_module(e)


class EvidenceTests(unittest.TestCase):
    def test_duplicate_key_rejected(self):
        with self.assertRaises(ValueError):
            json.loads('{"models":{},"models":{}}', object_pairs_hook=e.pairs)

    def test_batch_is_atomic_and_stale_or_unsourced_batch_cannot_replace_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / 'routing/model-evidence.json'
            e.write(target, {'schema_version': 2, 'evidence_as_of': '2020-01-01', 'sources': {}, 'alias_index': {'p/m': 'm'}, 'models': {'m': {}}})
            e.write(root / 'routing/model-roster.json', {'eligible_models': [{'id': 'p/m'}]})
            before = target.read_bytes()
            batch = {'base_sha256': 'stale', 'models': {'m': {'positioning': 'new'}}}
            with self.assertRaises(ValueError):
                e.apply(root, batch)
            batch['base_sha256'] = e.digest(target)
            batch['models']['m'] = {'capabilities': {'coding': {'rating': 'strong', 'confidence': 'high', 'evidence': ['missing']}}}
            with self.assertRaises(ValueError):
                e.apply(root, batch)
            self.assertEqual(target.read_bytes(), before)
            batch['models']['m'] = {'research_gaps': ['Searched; no published score found']}
            e.apply(root, batch)
            self.assertEqual(e.read(target)['evidence_as_of'], '2020-01-01')
            self.assertEqual(e.read(target)['models']['m']['research_gaps'], batch['models']['m']['research_gaps'])

    def test_context_evidence_and_inventory_aliases_are_validated(self):
        errors = e.validate({'schema_version': 2, 'models': {'m': {'context': {'input_tokens': -1, 'evidence': ['missing']}}}, 'alias_index': {}, 'sources': {}}, {'eligible_models': [{'id': 'p/m'}]})
        self.assertEqual(len(errors), 3)

    def test_interrupted_commit_replays_and_os_lock_is_released(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / 'routing/model-evidence.json'
            e.write(target, {'schema_version': 2, 'sources': {}, 'alias_index': {'p/m': 'm'}, 'models': {'m': {}}})
            e.write(root / 'routing/model-roster.json', {'eligible_models': [{'id': 'p/m'}]})
            batch = {'base_sha256': e.digest(target), 'models': {'m': {'research_gaps': ['checked']}}}
            original = e.write
            def interrupted(path, value):
                if value.get('status') == 'applied':
                    raise OSError('simulated interruption after cache replacement')
                original(path, value)
            with patch.object(e, 'write', interrupted), self.assertRaises(OSError):
                e.apply(root, batch)
            self.assertEqual(e.read(target)['models']['m']['research_gaps'], ['checked'])
            self.assertTrue(e.apply(root, batch)['already_applied'])
            self.assertTrue(e.apply(root, batch)['already_applied'])

    def test_capture_proof_is_checked_against_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / 'routing/model-evidence.json'
            e.write(target, {'schema_version': 2, 'sources': {}, 'alias_index': {'p/m': 'm'}, 'models': {'m': {}}})
            e.write(root / 'routing/model-roster.json', {'eligible_models': [{'id': 'p/m'}]})
            content = b'public model card'
            proof = {'url': 'https://example.org/card', 'retrieved_at': '2020-01-01T00:00:00Z', 'sha256': e.hashlib.sha256(content).hexdigest()}
            capture = e.hashlib.sha256(json.dumps(proof, sort_keys=True).encode()).hexdigest()
            e.write(root / f'.state/evidence/captures/{capture}.json', proof)
            source = root / f'.state/evidence/captures/{capture}.source'
            source.write_bytes(b'changed')
            batch = {'base_sha256': e.digest(target), 'models': {'m': {'source_keys': ['card']}}, 'sources': {'card': {**proof, 'capture_id': capture}}}
            with self.assertRaises(ValueError):
                e.apply(root, batch)
            source.write_bytes(content)
            self.assertEqual(e.apply(root, batch)['accepted_models'], ['m'])


if __name__ == '__main__':
    unittest.main()
