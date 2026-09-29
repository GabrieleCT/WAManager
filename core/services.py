import random
from collections import defaultdict
from .models import Lezione, Presenza, Match, Role


def generate_matches(lezione_id):
    """
    Algoritmo di abbinamento coppie per una data lezione.
    - Seleziona gli allievi con presenza confermata (presente=True).
    - Risolve i ruoli "BOTH" per equilibrare i numeri.
    - Genera coppie evitando abbinamenti già avvenuti nelle ultime 3 lezioni dello stesso corso.
    - Gestisce la disparità assegnando il flag "is_rotation=True" a chi resta spaiato.
    """
    lezione = Lezione.objects.get(id=lezione_id)

    # 1. Pulisci match pregressi per questa lezione in caso di ricalcolo
    Match.objects.filter(lezione=lezione).delete()

    presenze = Presenza.objects.filter(lezione=lezione, presente=True).select_related('allievo')

    leaders = []
    followers = []
    both = []

    # Estrai i ruoli in base all'anagrafica allievo
    for p in presenze:
        allievo = p.allievo
        if allievo.ruolo == Role.LEADER:
            leaders.append(allievo)
        elif allievo.ruolo == Role.FOLLOWER:
            followers.append(allievo)
        elif allievo.ruolo == Role.BOTH:
            both.append(allievo)

    # 2. Bilancia ruoli BOTH
    random.shuffle(both)
    for allievo in both:
        if len(leaders) <= len(followers):
            leaders.append(allievo)
        else:
            followers.append(allievo)

    # 3. Storico delle ultime 3 lezioni dello stesso corso per evitare ripetizioni
    recent_lezioni = Lezione.objects.filter(
        corso=lezione.corso,
        data__lt=lezione.data
    ).order_by('-data')[:3]

    history = defaultdict(set)
    for past_lezione in recent_lezioni:
        past_matches = Match.objects.filter(
            lezione=past_lezione, is_rotation=False
        ).select_related('leader', 'follower')
        for m in past_matches:
            if m.leader and m.follower:
                history[m.leader.id].add(m.follower.id)
                history[m.follower.id].add(m.leader.id)

    # 4. Algoritmo di matching
    random.shuffle(leaders)
    random.shuffle(followers)

    pairs = []
    unmatched_followers = list(followers)

    for leader in leaders:
        matched = None
        # Prova prima partner mai incontrati recentemente
        for follower in unmatched_followers:
            if follower.id not in history[leader.id]:
                matched = follower
                break

        # Se tutti già incontrati, fallback sul primo follower disponibile
        if not matched and unmatched_followers:
            matched = unmatched_followers[0]

        if matched:
            pairs.append((leader, matched))
            unmatched_followers.remove(matched)

    # 5. Salva i match nel database
    matches_to_create = []

    for leader, follower in pairs:
        matches_to_create.append(Match(
            lezione=lezione,
            leader=leader,
            follower=follower,
            is_rotation=False
        ))

    # Surplus di leader -> rotazione
    matched_leaders = {lead for lead, _ in pairs}
    for leader in leaders:
        if leader not in matched_leaders:
            matches_to_create.append(Match(
                lezione=lezione,
                leader=leader,
                follower=None,
                is_rotation=True
            ))

    # Surplus di follower -> rotazione
    for follower in unmatched_followers:
        matches_to_create.append(Match(
            lezione=lezione,
            leader=None,
            follower=follower,
            is_rotation=True
        ))

    Match.objects.bulk_create(matches_to_create)

    return {
        'pairs_count': len(pairs),
        'rotating_leaders': sum(1 for m in matches_to_create if m.is_rotation and m.leader),
        'rotating_followers': sum(1 for m in matches_to_create if m.is_rotation and m.follower)
    }

